resource "aws_db_subnet_group" "n8n" {
  name = "n8n-database-subnet-group"
  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "N8N DB subnet group"
  }
}

resource "aws_db_instance" "n8n" {
  identifier            = "n8n-postgres"
  engine                = "postgres"
  engine_version        = "15.7"
  instance_class        = "db.t3.micro"
  allocated_storage     = 10
  max_allocated_storage = 20 # Free tier requirement

  db_name = var.db_name
  username = var.db_username
  password = var.db_password

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.n8n.name
  vpc_security_group_ids = [aws_security_group.n8n_rds_sg.id]
  publicly_accessible    = false
  multi_az               = false

  storage_type            = "gp2"
  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = {
    Name = "n8n-postgres"
  }
}