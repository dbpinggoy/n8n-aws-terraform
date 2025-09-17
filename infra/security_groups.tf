# Security Group for EC2
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # n8n web interface (direct access when no domain is configured)
  dynamic "ingress" {
    for_each = var.domain_name == "" ? [1] : []
    content {
      from_port   = 5678
      to_port     = 5678
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
    }
  }

  # n8n web interface from ALB (when domain is configured)
  dynamic "ingress" {
    for_each = var.domain_name != "" ? [1] : []
    content {
      from_port       = 5678
      to_port         = 5678
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
    }
  }

  # HTTP access (for Let's Encrypt or web access) - only when no domain
  dynamic "ingress" {
    for_each = var.domain_name == "" ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
    }
  }

  # HTTPS access - only when no domain
  dynamic "ingress" {
    for_each = var.domain_name == "" ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
    }
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL access from EC2 only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}