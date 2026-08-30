variable "aws_region" {
  description = "AWS region used by the provider."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI role, in owner/repository format."
  type        = string
}

variable "private_backup_bucket_name" {
  description = "Private S3 bucket containing the CI database fixture."
  type        = string
}

variable "ci_prefix" {
  description = "S3 prefix containing CI database fixtures."
  type        = string
  default     = "ci"
}

variable "role_name" {
  description = "IAM role assumed by GitHub Actions."
  type        = string
  default     = "github-sanjusto-presupuesto-ci"
}

variable "tags" {
  description = "Tags applied to supported AWS resources."
  type        = map(string)
  default     = {}
}