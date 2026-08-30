output "github_actions_role_arn" {
  description = "IAM role ARN to use from GitHub Actions."
  value       = aws_iam_role.github_ci.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}