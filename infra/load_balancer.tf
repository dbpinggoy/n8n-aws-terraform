# Application Load Balancer (only created if domain is specified)
resource "aws_lb" "n8n" {
  count              = var.domain_name != "" ? 1 : 0
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2[0].id]

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Additional public subnet for ALB (ALB requires 2+ subnets in different AZs)
resource "aws_subnet" "public_2" {
  count                   = var.domain_name != "" ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-2"
    Environment = var.environment
  }
}

# Route table association for second public subnet
resource "aws_route_table_association" "public_2" {
  count          = var.domain_name != "" ? 1 : 0
  subnet_id      = aws_subnet.public_2[0].id
  route_table_id = aws_route_table.public.id
}

# Target Group for n8n
resource "aws_lb_target_group" "n8n" {
  count    = var.domain_name != "" ? 1 : 0
  name     = "${var.project_name}-tg"
  port     = 5678
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,401"  # n8n returns 401 for auth, which is healthy
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-target-group"
    Environment = var.environment
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "n8n" {
  count            = var.domain_name != "" ? 1 : 0
  target_group_arn = aws_lb_target_group.n8n[0].arn
  target_id        = aws_instance.n8n.id
  port             = 5678
}

# ALB Listener for HTTPS
resource "aws_lb_listener" "https" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.n8n[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.n8n[0].certificate_arn

  # Default action for n8n subdomain
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n[0].arn
  }
}

# ALB Listener Rule for base domain (redirect to n8n subdomain)
resource "aws_lb_listener_rule" "base_domain_redirect" {
  count        = var.domain_name != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      host        = "${var.subdomain}.${var.domain_name}"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

# ALB Listener for HTTP (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.n8n[0].arn
  port              = "80"
  protocol          = "HTTP"

  # Default action redirects to HTTPS n8n subdomain
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      host        = "${var.subdomain}.${var.domain_name}"
      status_code = "HTTP_301"
    }
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  count       = var.domain_name != "" ? 1 : 0
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = aws_vpc.main.id

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access (for redirect)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound to n8n (use VPC CIDR instead of security group reference to avoid cycle)
  egress {
    from_port   = 5678
    to_port     = 5678
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}