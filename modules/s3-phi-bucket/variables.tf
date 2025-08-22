variable "bucket_name" {
  description = "The name of the S3 bucket to create for PHI storage"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase alphanumeric characters and hyphens, and cannot start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "kms_key_id" {
  description = "The ARN of the KMS key to use for server-side encryption. This is required for PHI data protection."
  type        = string
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]+:key/[a-f0-9-]+$", var.kms_key_id))
    error_message = "The kms_key_id must be a valid KMS key ARN."
  }
}

variable "logging_bucket" {
  description = "The name of the S3 bucket to use for server access logging. If not provided, logging will be disabled."
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for server access logs. Defaults to the bucket name followed by a slash."
  type        = string
  default     = null
}

variable "trusted_principal_arns" {
  description = "List of IAM principal ARNs that should have access to this bucket"
  type        = list(string)
  default     = []
}

variable "trusted_principal_actions" {
  description = "List of S3 actions that trusted principals are allowed to perform"
  type        = list(string)
  default = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:GetBucketLocation",
    "s3:GetObjectVersion",
    "s3:PutObjectAcl",
    "s3:GetObjectAcl",
    "s3:GetBucketVersioning",
    "s3:PutBucketVersioning"
  ]
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for immutability. Note: This cannot be disabled once enabled."
  type        = bool
  default     = false
}

variable "object_lock_configuration" {
  description = "Object Lock configuration for the bucket. Required if enable_object_lock is true."
  type = object({
    mode = string # GOVERNANCE or COMPLIANCE
    days = number
  })
  default = null
  validation {
    condition = var.object_lock_configuration == null || (
      var.object_lock_configuration != null &&
      contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_configuration.mode) &&
      var.object_lock_configuration.days > 0
    )
    error_message = "Object Lock mode must be either GOVERNANCE or COMPLIANCE, and days must be greater than 0."
  }
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
  type = list(object({
    id      = string
    enabled = bool
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration_days = optional(number)
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    noncurrent_version_expiration_days = optional(number)
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules for the bucket"
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = null
}

variable "additional_policy_statements" {
  description = "Additional policy statements to add to the bucket policy"
  type = list(object({
    sid    = optional(string)
    effect = string
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })), [])
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to the bucket"
  type        = map(string)
  default     = {}
}