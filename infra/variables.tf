variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "n8n-project"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "n8ndb"
}

variable "my_ip" {
  description = "Your IP address for SSH access (use 0.0.0.0/0 for any IP - not recommended for production)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/n8n_key.pub"
}

variable "domain_name" {
  description = "Domain name for n8n (e.g., n8n.yourdomain.com). Leave empty to use IP only"
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Whether to create a new Route 53 hosted zone (set false if you manage DNS elsewhere)"
  type        = bool
  default     = false
}

variable "subdomain" {
  description = "Subdomain for n8n (will create subdomain.domain_name)"
  type        = string
  default     = "n8n"
}