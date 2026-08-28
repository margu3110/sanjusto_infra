output "ingress_bucket_name" {
  description = "Name of the backup ingress bucket."
  value       = aws_s3_bucket.ingress.bucket
}

output "ingress_bucket_arn" {
  description = "ARN of the backup ingress bucket."
  value       = aws_s3_bucket.ingress.arn
}

output "private_bucket_name" {
  description = "Name of the private backup bucket."
  value       = aws_s3_bucket.private.bucket
}

output "private_bucket_arn" {
  description = "ARN of the private backup bucket."
  value       = aws_s3_bucket.private.arn
}

output "region" {
  description = "AWS region containing the backup buckets."
  value       = data.aws_region.current.region
}

output "backup_copy_lambda_name" {
  description = "Name of the Lambda function that copies backups to private storage."
  value       = aws_lambda_function.backup_copy.function_name
}

output "backup_copy_lambda_arn" {
  description = "ARN of the Lambda function that copies backups to private storage."
  value       = aws_lambda_function.backup_copy.arn
}

output "backup_copy_lambda_role_arn" {
  description = "ARN of the IAM role used by the backup copy Lambda."
  value       = aws_iam_role.backup_copy_lambda.arn
}

output "backup_uploader_user_name" {
  description = "IAM user used by the LAMP server to upload backups."
  value       = aws_iam_user.backup_uploader.name
}
