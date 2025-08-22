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

# Create KMS key for PHI encryption (required)
resource "aws_kms_key" "phi_key" {
  description             = "KMS key for PHI S3 bucket encryption - basic example"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Purpose = "PHI-Encryption"
    Example = "Basic"
  }
}

resource "aws_kms_alias" "phi_key_alias" {
  name          = "alias/phi-s3-encryption-basic"
  target_key_id = aws_kms_key.phi_key.key_id
}

# Basic PHI bucket with mandatory KMS encryption
module "phi_bucket_basic" {
  source = "../../modules/s3-phi-bucket"

  bucket_name = "my-org-phi-data-basic-example"
  environment = "dev"

  # KMS encryption is mandatory
  kms_key_id = aws_kms_key.phi_key.arn

  # Define trusted principals who can access the bucket
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/PHIAccessRole",
    "arn:aws:iam::123456789012:user/phi-admin"
  ]

  tags = {
    Department = "Healthcare"
    DataType   = "PHI"
    Example    = "Basic"
  }
}

# Output the bucket details
output "bucket_id" {
  value = module.phi_bucket_basic.bucket_id
}

output "bucket_arn" {
  value = module.phi_bucket_basic.bucket_arn
}

output "kms_key_id" {
  value = aws_kms_key.phi_key.id
}

output "kms_key_arn" {
  value = aws_kms_key.phi_key.arn
}

output "encryption_configuration" {
  value = module.phi_bucket_basic.encryption_configuration
}