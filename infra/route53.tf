# Route 53 Hosted Zone (optional - only if create_route53_zone is true)
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" && var.create_route53_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name        = "${var.project_name}-zone"
    Environment = var.environment
  }
}

# Data source for existing hosted zone (if not creating new one)
data "aws_route53_zone" "existing" {
  count = var.domain_name != "" && !var.create_route53_zone ? 1 : 0
  name  = var.domain_name
}

# Local values for zone ID
locals {
  zone_id = var.domain_name != "" ? (
    var.create_route53_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  ) : ""
  
  full_domain = var.domain_name != "" ? "${var.subdomain}.${var.domain_name}" : ""
}

# ACM Certificate
resource "aws_acm_certificate" "n8n" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = local.full_domain
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-certificate"
    Environment = var.environment
  }
}

# Certificate validation DNS records
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.n8n[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "n8n" {
  count           = var.domain_name != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.n8n[0].arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]

  timeouts {
    create = "20m"
  }
}

# A record pointing to ALB for n8n subdomain
resource "aws_route53_record" "n8n" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = local.full_domain
  type    = "A"

  alias {
    name                   = aws_lb.n8n[0].dns_name
    zone_id                = aws_lb.n8n[0].zone_id
    evaluate_target_health = true
  }
}

# A record pointing to ALB for base domain (fixes certificate issues)
resource "aws_route53_record" "base_domain" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.n8n[0].dns_name
    zone_id                = aws_lb.n8n[0].zone_id
    evaluate_target_health = true
  }
}