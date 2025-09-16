# Application load balancer for n8n
resource "aws_lb" "n8n" {
  name               = "n8n-alb"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  security_groups = [
    aws_security_group.n8n_default_sg.id
  ]
}

resource "aws_lb_target_group" "n8n" {
  name     = "n8n-tg"
  port     = 5678
  protocol = "HTTP"
  vpc_id   = aws_vpc.n8n.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "n8n-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.n8n.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n.arn
  }
}