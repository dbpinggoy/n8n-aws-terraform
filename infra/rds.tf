# Generate random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store DB password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password-${random_string.suffix.result}"
  description             = "Password for ${var.project_name} PostgreSQL database"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-db-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "n8nuser"
    password = random_password.db_password.result
  })
}

# Random suffix for secret name uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier            = "${var.project_name}-postgres"
  engine                = "postgres"
  engine_version        = "15.7"
  instance_class        = var.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = var.db_name
  username = jsondecode(aws_secretsmanager_secret_version.db_password.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.db_password.secret_string)["password"]

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot = true  # Set to false in production
  deletion_protection = false # Set to true in production

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = var.environment
  }
}

# IAM Role for EC2 to access Secrets Manager
resource "aws_iam_role" "ec2_secrets_role" {
  name = "${var.project_name}-ec2-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "ec2_secrets_policy" {
  name = "${var.project_name}-ec2-secrets-policy"
  role = aws_iam_role.ec2_secrets_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_secrets_role.name
}