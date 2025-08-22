terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

locals {
  enable_object_lock = var.enable_object_lock && var.object_lock_configuration != null
}

# S3 Bucket for PHI Storage
resource "aws_s3_bucket" "phi_bucket" {
  bucket              = var.bucket_name
  object_lock_enabled = local.enable_object_lock

  tags = merge(
    var.tags,
    {
      Purpose     = "PHI Storage"
      Compliance  = "HIPAA"
      Environment = var.environment
    }
  )
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "phi_bucket_pab" {
  bucket = aws_s3_bucket.phi_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "phi_bucket_versioning" {
  bucket = aws_s3_bucket.phi_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption configuration with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "phi_bucket_encryption" {
  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Server access logging
resource "aws_s3_bucket_logging" "phi_bucket_logging" {
  count = var.logging_bucket != null ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  target_bucket = var.logging_bucket
  target_prefix = var.logging_prefix != null ? var.logging_prefix : "${var.bucket_name}/"
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "phi_bucket_lifecycle" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", null) != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_version_transitions", [])
        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration_days", null) != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }
}

# Object Lock Configuration (Bonus Feature)
resource "aws_s3_bucket_object_lock_configuration" "phi_bucket_object_lock" {
  count = local.enable_object_lock ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  rule {
    default_retention {
      mode = var.object_lock_configuration.mode
      days = var.object_lock_configuration.days
    }
  }
}

# Bucket policy for secure access and encryption in transit
data "aws_iam_policy_document" "phi_bucket_policy" {
  # Deny all requests that are not using HTTPS (enforce encryption in transit)
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.phi_bucket.arn,
      "${aws_s3_bucket.phi_bucket.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow access only from trusted IAM principals
  dynamic "statement" {
    for_each = length(var.trusted_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowTrustedPrincipals"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.trusted_principal_arns
      }
      actions = var.trusted_principal_actions
      resources = [
        aws_s3_bucket.phi_bucket.arn,
        "${aws_s3_bucket.phi_bucket.arn}/*"
      ]
    }
  }

  # Require KMS encryption headers for PUT requests
  statement {
    sid    = "RequireKMSEncryptionHeaders"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  # Ensure the correct KMS key is used
  statement {
    sid    = "RequireCorrectKMSKey"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.phi_bucket.arn}/*"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [var.kms_key_id]
    }
  }

  # Additional custom policy statements
  dynamic "statement" {
    for_each = var.additional_policy_statements
    content {
      sid       = lookup(statement.value, "sid", null)
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = lookup(statement.value, "conditions", [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "phi_bucket_policy" {
  bucket = aws_s3_bucket.phi_bucket.id
  policy = data.aws_iam_policy_document.phi_bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.phi_bucket_pab
  ]
}

# CORS configuration (optional)
resource "aws_s3_bucket_cors_configuration" "phi_bucket_cors" {
  count = var.cors_rules != null ? 1 : 0

  bucket = aws_s3_bucket.phi_bucket.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}