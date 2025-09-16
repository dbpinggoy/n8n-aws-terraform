variable "az_a" {
  description = "Primary availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "az_b" {
  description = "Secondary availability zone"
  type        = string
  default     = "us-east-1b"
}

variable "db_name" {
  description = "The database name for the n8n database"
  type        = string
}

variable "db_username" {
  description = "The username for the n8n database"
  type        = string
}

variable "db_password" {
  description = "The password for the n8n database"
  type        = string
  sensitive   = true
}


variable "domain_name" {
  description = "The domain name for n8n"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "The Hosted Zone ID in Route 53"
  type        = string
  default     = null
}