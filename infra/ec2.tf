# Key Pair for EC2 access
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path) # Configurable SSH key path
}

# EC2 Instance
resource "aws_instance" "n8n" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  key_name                = aws_key_pair.main.key_name
  vpc_security_group_ids  = [aws_security_group.ec2.id]
  subnet_id               = aws_subnet.public.id
  associate_public_ip_address = true
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name

  # User data script to install Docker and prepare for n8n
  user_data = base64encode(templatefile("${path.module}/../scripts/install_n8n.sh", {
    db_host               = aws_db_instance.postgres.endpoint
    db_name               = aws_db_instance.postgres.db_name
    secret_arn            = aws_secretsmanager_secret.db_password.arn
    aws_region            = var.aws_region
    domain_configured     = var.domain_name != "" ? "true" : "false"
    n8n_protocol          = var.domain_name != "" ? "https" : "http"
    n8n_editor_base_url   = var.domain_name != "" ? "https://${var.subdomain}.${var.domain_name}/" : "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5678/"
    webhook_url           = var.domain_name != "" ? "https://${var.subdomain}.${var.domain_name}/" : "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5678/"
    full_domain           = var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : ""
  }))

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }

  depends_on = [aws_db_instance.postgres]
}

# Elastic IP for EC2 (optional, for fixed IP)
resource "aws_eip" "n8n" {
  instance = aws_instance.n8n.id
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}