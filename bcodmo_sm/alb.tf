resource "aws_alb" "sm_ui" {
  name            = "sm-ui-${terraform.workspace}"
  subnets         = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
  security_groups = [aws_security_group.sm_ui.id]
}

resource "aws_alb_target_group" "sm_ui" {
  name        = "sm-ui-tgroup-${terraform.workspace}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "instance"
  health_check {
    timeout  = 120
    interval = 300

  }

}

resource "aws_alb_target_group_attachment" "sm_ui" {
  target_group_arn = aws_alb_target_group.sm_ui.arn
  target_id        = aws_instance.instance.id
  port             = 80
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.sm_ui.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn


  default_action {
    target_group_arn = aws_alb_target_group.sm_ui.id
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



output "alb_sm_ui_dns" {
  value       = aws_alb.sm_ui.dns_name
  description = "The DNS of the SM UI application load balancer"
}

