output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.n8n.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.n8n.public_dns
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.postgres.db_name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "n8n_url" {
  description = "URL to access n8n interface"
  value       = var.domain_name != "" ? "https://${var.subdomain}.${var.domain_name}" : "http://${aws_eip.n8n.public_ip}:5678"
}

output "domain_name" {
  description = "Full domain name for n8n (if configured)"
  value       = var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : "Not configured"
}

output "certificate_arn" {
  description = "ARN of the ACM certificate (if domain is configured)"
  value       = var.domain_name != "" ? aws_acm_certificate.n8n[0].arn : "Not configured"
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer (if domain is configured)"
  value       = var.domain_name != "" ? aws_lb.n8n[0].dns_name : "Not configured"
}

output "nameservers" {
  description = "Route 53 nameservers (if new hosted zone was created)"
  value       = var.domain_name != "" && var.create_route53_zone ? aws_route53_zone.main[0].name_servers : []
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ~/.ssh/n8n_key ubuntu@${aws_eip.n8n.public_ip}"
}