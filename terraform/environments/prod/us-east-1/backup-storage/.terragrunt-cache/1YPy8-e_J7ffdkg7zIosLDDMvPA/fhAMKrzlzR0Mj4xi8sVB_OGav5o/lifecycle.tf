resource "aws_s3_bucket_lifecycle_configuration" "ingress" {
  bucket = aws_s3_bucket.ingress.id

  rule {
    id     = "expire-ingress-backups"
    status = "Enabled"

    filter {
      prefix = "mysql/"
    }

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "private" {
  bucket = aws_s3_bucket.private.id

  rule {
    id     = "retain-private-backups"
    status = "Enabled"

    filter {
      prefix = "mysql/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
