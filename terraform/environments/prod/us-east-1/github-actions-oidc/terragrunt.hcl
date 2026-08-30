terraform {
  source = "../../../../modules/github-actions-oidc"

  extra_arguments "aws_profile" {
    commands = [
      "init",
      "validate",
      "plan",
      "apply",
      "destroy",
      "refresh",
      "import"
    ]

    env_vars = {
      AWS_PROFILE = "lino"
      AWS_REGION  = "us-east-1"
    }
  }
}

locals {
  project     = "sanjusto"
  environment = "prod"
  aws_region  = "us-east-1"
}

inputs = {
  aws_region = local.aws_region

  github_repository = "margu3110/sanjusto_presupuesto"

  private_backup_bucket_name = "sanjusto-945824236743-backups-private"

  ci_prefix = "ci"

  role_name = "github-sanjusto-presupuesto-ci"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "Terraform"
    Purpose     = "GitHubActionsCI"
    AWSRegion   = local.aws_region
  }
}