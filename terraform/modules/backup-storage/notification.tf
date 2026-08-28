resource "aws_lambda_permission" "backup_copy" {
  statement_id  = "AllowS3InvokeBackupCopy"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_copy.function_name
  principal     = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.ingress.arn
}

resource "aws_s3_bucket_notification" "ingress" {
  bucket = aws_s3_bucket.ingress.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.backup_copy.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "mysql/"
  }

  depends_on = [
    aws_lambda_permission.backup_copy
  ]
}