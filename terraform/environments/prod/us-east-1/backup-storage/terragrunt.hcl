terraform {
  source = "../../../../modules/backup-storage"

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
  aws_region  = local.aws_region
  name_prefix = local.project
  environment = local.environment

  tags = {
    AWSRegion = local.aws_region
  }
}