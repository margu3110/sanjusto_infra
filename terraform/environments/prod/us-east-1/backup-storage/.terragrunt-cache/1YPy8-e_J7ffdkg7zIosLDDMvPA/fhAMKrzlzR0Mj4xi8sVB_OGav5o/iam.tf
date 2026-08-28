resource "aws_iam_role" "backup_copy_lambda" {
  name = "${var.name_prefix}-backup-copy-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-backup-copy-lambda"
      Role = "backup-copy-lambda"
    }
  )
}

resource "aws_iam_role_policy" "backup_copy_lambda" {
  name = "${var.name_prefix}-backup-copy-lambda"
  role = aws_iam_role.backup_copy_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadIngressBackups"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.ingress.arn}/mysql/*"
      },
      {
        Sid    = "WritePrivateBackups"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.private.arn}/mysql/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_copy_lambda_logs" {
  role       = aws_iam_role.backup_copy_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
