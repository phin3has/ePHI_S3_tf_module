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
resource "aws_kms_key" "phi_archive_key" {
  description             = "KMS key for PHI archive S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Purpose = "PHI-Archive-Encryption"
  }
}

resource "aws_kms_alias" "phi_archive_key_alias" {
  name          = "alias/phi-archive-s3-encryption"
  target_key_id = aws_kms_key.phi_archive_key.key_id
}

# Create the logging bucket
resource "aws_s3_bucket" "archive_logging_bucket" {
  bucket = "my-org-s3-archive-logs-example"

  tags = {
    Purpose = "S3-Archive-Access-Logs"
  }
}

resource "aws_s3_bucket_public_access_block" "archive_logging_bucket_pab" {
  bucket = aws_s3_bucket.archive_logging_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive_logging_bucket_encryption" {
  bucket = aws_s3_bucket.archive_logging_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# PHI archive bucket with Object Lock for immutability
module "phi_bucket_archive" {
  source = "../../modules/s3-phi-bucket"

  bucket_name = "my-org-phi-archive-immutable-example"
  environment = "prod"

  # Enable Object Lock for WORM compliance
  enable_object_lock = true
  object_lock_configuration = {
    mode = "COMPLIANCE"  # Cannot be overridden by anyone
    days = 2555          # 7 years retention for HIPAA compliance
  }

  # KMS encryption is mandatory
  kms_key_id = aws_kms_key.phi_archive_key.arn

  # Enable logging
  logging_bucket = aws_s3_bucket.archive_logging_bucket.id
  logging_prefix = "phi-archive/"

  # Define trusted principals - read-only for archive
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/PHIArchiveWriteRole",
    "arn:aws:iam::123456789012:role/PHIArchiveReadRole",
    "arn:aws:iam::123456789012:role/ComplianceAuditorRole"
  ]

  # Custom actions for archive scenario
  trusted_principal_actions = [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:GetObjectRetention",
    "s3:GetObjectLegalHold",
    "s3:ListBucket",
    "s3:GetBucketLocation",
    "s3:GetBucketVersioning",
    "s3:PutObject",  # Allow putting new objects
    "s3:PutObjectRetention"  # Allow setting retention on objects
  ]

  # Lifecycle rules for long-term archival
  lifecycle_rules = [
    {
      id      = "archive-strategy"
      enabled = true
      transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        },
        {
          days          = 1095  # 3 years
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ]
      # Keep noncurrent versions for the full retention period
      noncurrent_version_expiration_days = 2555
    }
  ]

  # Additional policy to enforce minimum retention
  additional_policy_statements = [
    {
      sid    = "EnforceMinimumRetention"
      effect = "Deny"
      principals = [
        {
          type        = "*"
          identifiers = ["*"]
        }
      ]
      actions = [
        "s3:BypassGovernanceRetention",
        "s3:DeleteObjectVersion"
      ]
      resources = [
        "arn:aws:s3:::my-org-phi-archive-immutable-example/*"
      ]
    }
  ]

  tags = {
    Department      = "Healthcare"
    DataType        = "PHI"
    Compliance      = "HIPAA"
    RetentionYears  = "7"
    Immutable       = "true"
    Example         = "Object-Lock"
  }

  depends_on = [
    aws_s3_bucket.archive_logging_bucket
  ]
}

# Outputs
output "bucket_id" {
  value = module.phi_bucket_archive.bucket_id
}

output "bucket_arn" {
  value = module.phi_bucket_archive.bucket_arn
}

output "kms_key_id" {
  value = aws_kms_key.phi_archive_key.id
}

output "object_lock_enabled" {
  value = module.phi_bucket_archive.object_lock_enabled
}

output "object_lock_configuration" {
  value = module.phi_bucket_archive.object_lock_configuration
}

output "encryption_configuration" {
  value = module.phi_bucket_archive.encryption_configuration
}

output "logging_configuration" {
  value = module.phi_bucket_archive.logging_configuration
}