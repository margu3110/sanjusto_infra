data "archive_file" "backup_copy_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/backup-copy.py"
  output_path = "${path.module}/lambda/backup-copy.zip"
}

resource "aws_lambda_function" "backup_copy" {
  function_name = "${var.name_prefix}-backup-copy"

  description = "Copies MySQL backups from the ingress bucket to the private backup bucket."

  role = aws_iam_role.backup_copy_lambda.arn

  runtime = "python3.13"
  handler = "backup-copy.lambda_handler"

  filename         = data.archive_file.backup_copy_lambda.output_path
  source_code_hash = data.archive_file.backup_copy_lambda.output_base64sha256

  timeout     = 60
  memory_size = 128

  environment {
    variables = {
      PRIVATE_BUCKET = aws_s3_bucket.private.bucket
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-backup-copy"
      Role = "backup-copy"
    }
  )
}
