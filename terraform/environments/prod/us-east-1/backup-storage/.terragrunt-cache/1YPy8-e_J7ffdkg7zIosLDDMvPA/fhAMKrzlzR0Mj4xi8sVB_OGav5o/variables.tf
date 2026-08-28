variable "name_prefix" {
  description = "Prefix used for San Justo backup resources."
  type        = string
  default     = "sanjusto"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region where the resources will be created."
  type        = string
}