provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket = "sctp-ce8-tfstate"
    key    = "xinwei-s3-tf-ci.tfstate"
    region = "ap-southeast-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = split("/", data.aws_caller_identity.current.arn)[1]
  account_id  = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "s3_tf" {
  bucket = "${replace(local.name_prefix, "/[^a-z0-9-]/", "")}-s3-tf-bkt-${local.account_id}"
}

# ✅ Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.s3_tf.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# ✅ Versioning
resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.s3_tf.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ✅ Public Access Block
resource "aws_s3_bucket_public_access_block" "s3_public_access" {
  bucket                  = aws_s3_bucket.s3_tf.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ✅ Access Logging
resource "aws_s3_bucket_logging" "s3_logging" {
  bucket        = aws_s3_bucket.s3_tf.id
  target_bucket = "arn:aws:s3:::your-logging-bucket"
  target_prefix = "log/"
}

# ✅ Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "s3_lifecycle" {
  bucket = aws_s3_bucket.s3_tf.id
  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ✅ Event Notifications
resource "aws_s3_bucket_notification" "s3_notifications" {
  bucket = aws_s3_bucket.s3_tf.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_event_handler.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
