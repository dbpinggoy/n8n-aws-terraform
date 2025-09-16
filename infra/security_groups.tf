resource "aws_security_group" "n8n_default_sg" {
  name   = "n8n-sg"
  vpc_id = aws_vpc.n8n.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.n8n.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "n8n_rds_sg" {
  name        = "n8n-rds-sg"
  description = "Allow n8n ECS to access RDS"
  vpc_id      = aws_vpc.n8n.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.n8n.cidr_block]
  }

  ingress {
    description = "Allow access from my IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["221.121.101.201/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "n8n-rds-sg"
  }
}