terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create a KMS key for PHI encryption
resource "aws_kms_key" "phi_key" {
  description             = "KMS key for PHI S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Purpose = "PHI-Encryption"
  }
}

resource "aws_kms_alias" "phi_key_alias" {
  name          = "alias/phi-s3-encryption"
  target_key_id = aws_kms_key.phi_key.key_id
}

# Create the logging bucket
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "my-org-s3-access-logs-example"

  tags = {
    Purpose = "S3-Access-Logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logging_bucket_pab" {
  bucket = aws_s3_bucket.logging_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging_bucket_encryption" {
  bucket = aws_s3_bucket.logging_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# PHI bucket with mandatory KMS encryption and logging
module "phi_bucket_kms" {
  source = "../../modules/s3-phi-bucket"

  bucket_name = "my-org-phi-data-kms-example"
  environment = "staging"

  # KMS encryption is mandatory
  kms_key_id = aws_kms_key.phi_key.arn

  # Enable logging
  logging_bucket = aws_s3_bucket.logging_bucket.id
  logging_prefix = "phi-bucket/"

  # Define trusted principals
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/PHIAccessRole",
    "arn:aws:iam::123456789012:role/PHIReadOnlyRole"
  ]

  # Lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id      = "transition-old-data"
      enabled = true
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      noncurrent_version_transitions = [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        }
      ]
      noncurrent_version_expiration_days = 365
    }
  ]

  tags = {
    Department = "Healthcare"
    DataType   = "PHI"
    Example    = "KMS-Encryption"
    Logging    = "Enabled"
  }

  depends_on = [
    aws_s3_bucket.logging_bucket
  ]
}

# Outputs
output "bucket_id" {
  value = module.phi_bucket_kms.bucket_id
}

output "bucket_arn" {
  value = module.phi_bucket_kms.bucket_arn
}

output "kms_key_id" {
  value = aws_kms_key.phi_key.id
}

output "encryption_configuration" {
  value = module.phi_bucket_kms.encryption_configuration
}

output "logging_configuration" {
  value = module.phi_bucket_kms.logging_configuration
}