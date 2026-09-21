variable "environment" {
  description = "Environment name (used for tagging and state)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region. CloudFront certificates must be in us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "base_domain" {
  description = "Base domain managed in Route53."
  type        = string
}

variable "site_hostname" {
  description = "Hostname the static site is served on."
  type        = string
  default     = "docs.nexusauto.com.br"
}
