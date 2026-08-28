data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = merge(
    {
      Project     = "sanjusto"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "sanjusto_infra"
      Component   = "backup-storage"
    },
    var.tags
  )

  bucket_suffix = data.aws_caller_identity.current.account_id

  ingress_bucket = "${var.name_prefix}-${local.bucket_suffix}-backup-ingress"
  private_bucket = "${var.name_prefix}-${local.bucket_suffix}-backups-private"
}

resource "aws_s3_bucket" "ingress" {
  bucket = local.ingress_bucket

  tags = merge(
    local.common_tags,
    {
      Name = local.ingress_bucket
      Role = "backup-ingress"
    }
  )
}

resource "aws_s3_bucket" "private" {
  bucket = local.private_bucket

  tags = merge(
    local.common_tags,
    {
      Name = local.private_bucket
      Role = "backup-storage"
    }
  )
}

resource "aws_s3_bucket_versioning" "ingress" {
  bucket = aws_s3_bucket.ingress.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "private" {
  bucket = aws_s3_bucket.private.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ingress" {
  bucket = aws_s3_bucket.ingress.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private" {
  bucket = aws_s3_bucket.private.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ingress" {
  bucket = aws_s3_bucket.ingress.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
