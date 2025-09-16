output "rds_endpoint" {
  value = aws_db_instance.n8n.endpoint
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.n8n.dns_name
}

# output "n8n_url" {
#   value = "https://${var.domain_name}"
# }