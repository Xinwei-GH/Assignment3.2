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

# ✅ Encryption (KMS)
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

# ✅ Lifecycle Policy (Including Aborting Failed Uploads)
resource "aws_s3_bucket_lifecycle_configuration" "s3_lifecycle" {
  bucket = aws_s3_bucket.s3_tf.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # ✅ New Rule to Handle Incomplete Uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Adjust as needed
    }
  }
}

# ✅ SNS Topic for S3 Event Notifications
resource "aws_sns_topic" "s3_notifications_topic" {
  name = "s3-event-notifications"
}

# ✅ S3 Event Notification to SNS Topic
resource "aws_s3_bucket_notification" "s3_notifications" {
  bucket = aws_s3_bucket.s3_tf.id

  topic {
    topic_arn = aws_sns_topic.s3_notifications_topic.arn
    events    = ["s3:ObjectCreated:*"] # Modify event types as needed
  }
}

# ✅ IAM Policy to Allow S3 to Publish to SNS
resource "aws_sns_topic_policy" "sns_policy" {
  arn = aws_sns_topic.s3_notifications_topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.s3_notifications_topic.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.s3_tf.arn
          }
        }
      }
    ]
  })
}
