resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = var.tags
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "ci_backup_read" {
  statement {
    sid    = "ReadCiDatabaseFixture"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.private_backup_bucket_name}/${var.ci_prefix}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ci_backup_read" {
  name   = "read-ci-database-fixture"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.ci_backup_read.json
}