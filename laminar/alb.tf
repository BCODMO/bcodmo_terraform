resource "aws_alb" "laminar_web" {
  name            = "laminar-web-${var.environment[terraform.workspace]}"
  subnets         = [aws_subnet.subnet_public_a.id, aws_subnet.subnet_public_b.id]
  security_groups = [aws_security_group.laminar.id]
}

resource "aws_alb_target_group" "web" {
  name        = "laminar-web-tgroup-${var.environment[terraform.workspace]}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    timeout  = 120
    interval = 300

  }

}

# redirect all traffic from the alb to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.laminar_web.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn


  default_action {
    target_group_arn = aws_alb_target_group.web.id
    type             = "forward"
  }
}

resource "aws_alb_listener" "front_end_redirect" {
  load_balancer_arn = aws_alb.laminar_web.id
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb" "laminar_app" {
  name            = "laminar-app-${var.environment[terraform.workspace]}"
  subnets         = [aws_subnet.subnet_public_a.id, aws_subnet.subnet_public_b.id]
  security_groups = [aws_security_group.laminar.id]
}


resource "aws_alb_target_group" "app" {
  name        = "laminar-app-tgroup-${var.environment[terraform.workspace]}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path     = "/healthcheck/"
    timeout  = 120
    interval = 300

  }

}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "server" {
  load_balancer_arn = aws_alb.laminar_app.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}

# Must be imported in
resource "aws_acm_certificate" "cert" {
  domain_name       = "*.bco-dmo.org"
  validation_method = "NONE"
  options {
    certificate_transparency_logging_preference = "DISABLED"
  }
}



output "alb_web_dns" {
  value       = aws_alb.laminar_web.dns_name
  description = "The DNS of the web application load balancer"
}

output "alb_app_dns" {
  value       = aws_alb.laminar_app.dns_name
  description = "The DNS of the app application load balancer"
}
