output "bucket_id" {
  description = "The ID of the PHI S3 bucket"
  value       = aws_s3_bucket.phi_bucket.id
}

output "bucket_arn" {
  description = "The ARN of the PHI S3 bucket"
  value       = aws_s3_bucket.phi_bucket.arn
}

output "bucket_domain_name" {
  description = "The domain name of the PHI S3 bucket"
  value       = aws_s3_bucket.phi_bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the PHI S3 bucket"
  value       = aws_s3_bucket.phi_bucket.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region where the PHI S3 bucket is created"
  value       = aws_s3_bucket.phi_bucket.region
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = aws_s3_bucket.phi_bucket.hosted_zone_id
}

output "encryption_configuration" {
  description = "The KMS encryption configuration of the bucket"
  value = {
    sse_algorithm     = "aws:kms"
    kms_master_key_id = var.kms_key_id
  }
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket"
  value       = true
}

output "object_lock_enabled" {
  description = "Whether Object Lock is enabled on the bucket"
  value       = local.enable_object_lock
}

output "object_lock_configuration" {
  description = "The Object Lock configuration if enabled"
  value       = local.enable_object_lock ? var.object_lock_configuration : null
}

output "logging_configuration" {
  description = "The logging configuration of the bucket"
  value = var.logging_bucket != null ? {
    target_bucket = var.logging_bucket
    target_prefix = var.logging_prefix != null ? var.logging_prefix : "${var.bucket_name}/"
  } : null
}

output "public_access_block_configuration" {
  description = "The public access block configuration"
  value = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

output "bucket_policy_json" {
  description = "The JSON policy applied to the bucket"
  value       = data.aws_iam_policy_document.phi_bucket_policy.json
  sensitive   = true
}