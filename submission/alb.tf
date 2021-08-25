resource "aws_alb" "submission_go" {
  name            = "submission-go-${terraform.workspace}"
  subnets         = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
  security_groups = [aws_security_group.submission.id]
}

resource "aws_alb_target_group" "web" {
  name        = "submission-go-tgroup-${terraform.workspace}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "ip"
  health_check {
    timeout  = 120
    interval = 300

  }

}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.submission_go.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn


  default_action {
    target_group_arn = aws_alb_target_group.web.id
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
  value       = aws_alb.submission_go.dns_name
  description = "The DNS of the web application load balancer"
}
