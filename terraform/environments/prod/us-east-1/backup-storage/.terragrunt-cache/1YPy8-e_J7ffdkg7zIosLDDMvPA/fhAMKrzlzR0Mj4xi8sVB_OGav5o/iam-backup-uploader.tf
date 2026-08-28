resource "aws_iam_user" "backup_uploader" {
  name = "${var.name_prefix}-backup-uploader"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-backup-uploader"
      Role = "backup-uploader"
    }
  )
}

resource "aws_iam_user_policy" "backup_uploader" {
  name = "${var.name_prefix}-backup-uploader"
  user = aws_iam_user.backup_uploader.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "UploadMySQLBackups"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.ingress.arn}/mysql/*"
      }
    ]
  })
}
