provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "sctp-ce8-tfstate"
    key    = "xinwei-s3-tf-ci.tfstate" #Change this
    region = "ap-southeast-1"
  }
}

data "aws_caller_identity" "current" {}

locals {
  arn_parts   = split("/", data.aws_caller_identity.current.arn)
  name_prefix = length(arn_parts) > 1 ? arn_parts[1] : arn_parts[0] # Fallback if no "/"
  account_id  = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "s3_tf" {
  bucket = "${local.name_prefix}-s3-tf-bkt-${local.account_id}"
}