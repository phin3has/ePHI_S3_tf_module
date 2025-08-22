# Terraform Module: Secure S3 Bucket for PHI Storage

## Overview

This Terraform module provides a secure, HIPAA-compliant AWS S3 bucket specifically designed for storing Protected Health Information (PHI). It implements multiple layers of security controls and best practices to ensure data protection, compliance, and auditability.

## Features

### Core Security Controls

- **🔒 Public Access Blocking**: All public access is blocked by default
- **🔐 Encryption at Rest**: Mandatory KMS encryption for enhanced security
- **🔑 Encryption in Transit**: Enforced via bucket policy (HTTPS only)
- **📚 Object Versioning**: Enabled by default for data recovery
- **📝 Access Logging**: Optional server access logging to a separate bucket
- **👤 IAM-based Access Control**: Configurable trusted principals with least-privilege access
- **🔗 Object Lock** (Bonus): Optional immutability for compliance requirements

### Additional Features

- **Lifecycle Management**: Configurable lifecycle rules for cost optimization
- **CORS Configuration**: Optional CORS rules for web applications
- **Custom Policies**: Support for additional policy statements
- **Comprehensive Tagging**: Automatic compliance tags plus custom tags

## Usage

### Basic Example

```hcl
# Create KMS key for PHI encryption (required)
resource "aws_kms_key" "phi_key" {
  description             = "KMS key for PHI S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

module "phi_bucket" {
  source = "./modules/s3-phi-bucket"

  bucket_name = "my-organization-phi-data"
  environment = "prod"
  
  # KMS encryption is mandatory
  kms_key_id = aws_kms_key.phi_key.arn
  
  # Optional: Enable logging
  logging_bucket = "my-organization-s3-logs"
  
  # Define trusted principals
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/PHIAccessRole",
    "arn:aws:iam::123456789012:user/authorized-user"
  ]
  
  tags = {
    Department = "Healthcare"
    DataType   = "PHI"
  }
}
```

### Advanced Example with Object Lock

```hcl
module "phi_bucket_immutable" {
  source = "./modules/s3-phi-bucket"

  bucket_name = "my-organization-phi-archive"
  environment = "prod"
  
  # Enable Object Lock for immutability
  enable_object_lock = true
  object_lock_configuration = {
    mode = "COMPLIANCE"
    days = 2555  # 7 years retention
  }
  
  # Use customer-managed KMS key
  kms_key_id = aws_kms_key.phi_key.arn
  
  # Enable logging
  logging_bucket = "my-organization-s3-logs"
  logging_prefix = "phi-archive/"
  
  # Trusted principals with custom actions
  trusted_principal_arns = [
    "arn:aws:iam::123456789012:role/PHIArchiveRole"
  ]
  
  trusted_principal_actions = [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:ListBucket"
  ]
  
  # Lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id      = "archive-old-versions"
      enabled = true
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      noncurrent_version_expiration_days = 2555
    }
  ]
  
  tags = {
    Department   = "Healthcare"
    DataType     = "PHI"
    Retention    = "7-years"
    Compliance   = "HIPAA"
  }
}
```

## Input Variables

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `bucket_name` | `string` | Yes | - | The name of the S3 bucket to create for PHI storage |
| `environment` | `string` | No | `"prod"` | Environment name (dev, staging, prod, test) |
| `kms_key_id` | `string` | Yes | - | ARN of the KMS key for encryption (mandatory for PHI data protection) |
| `logging_bucket` | `string` | No | `null` | Name of the S3 bucket for server access logging |
| `logging_prefix` | `string` | No | `"<bucket_name>/"` | Prefix for server access logs |
| `trusted_principal_arns` | `list(string)` | No | `[]` | List of IAM principal ARNs with bucket access |
| `trusted_principal_actions` | `list(string)` | No | See below* | S3 actions allowed for trusted principals |
| `enable_object_lock` | `bool` | No | `false` | Enable S3 Object Lock (cannot be disabled once enabled) |
| `object_lock_configuration` | `object` | No | `null` | Object Lock configuration (required if enabled) |
| `lifecycle_rules` | `list(object)` | No | `[]` | Lifecycle rules for the bucket |
| `cors_rules` | `list(object)` | No | `null` | CORS rules for the bucket |
| `additional_policy_statements` | `list(object)` | No | `[]` | Additional policy statements for the bucket |
| `tags` | `map(string)` | No | `{}` | Additional tags to apply to the bucket |

*Default `trusted_principal_actions`:
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`
- `s3:ListBucket`, `s3:GetBucketLocation`
- `s3:GetObjectVersion`, `s3:PutObjectAcl`, `s3:GetObjectAcl`
- `s3:GetBucketVersioning`, `s3:PutBucketVersioning`

### Object Lock Configuration

When `enable_object_lock` is `true`, provide:

```hcl
object_lock_configuration = {
  mode = "GOVERNANCE" # or "COMPLIANCE"
  days = 365          # Retention period in days
}
```

- **GOVERNANCE**: Allows users with specific IAM permissions to override retention
- **COMPLIANCE**: No one can override retention, including the root user

### Lifecycle Rules Structure

```hcl
lifecycle_rules = [
  {
    id      = "rule-id"
    enabled = true
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    ]
    expiration_days = 365
    noncurrent_version_transitions = [
      {
        days          = 30
        storage_class = "GLACIER"
      }
    ]
    noncurrent_version_expiration_days = 730
  }
]
```

## Outputs

| Output | Description | Sensitive |
|--------|-------------|-----------|
| `bucket_id` | The ID of the PHI S3 bucket | No |
| `bucket_arn` | The ARN of the PHI S3 bucket | No |
| `bucket_domain_name` | The domain name of the PHI S3 bucket | No |
| `bucket_regional_domain_name` | The regional domain name of the PHI S3 bucket | No |
| `bucket_region` | The AWS region where the bucket is created | No |
| `bucket_hosted_zone_id` | The Route 53 Hosted Zone ID for this bucket's region | No |
| `encryption_configuration` | The encryption configuration of the bucket | No |
| `versioning_enabled` | Whether versioning is enabled (always true) | No |
| `object_lock_enabled` | Whether Object Lock is enabled | No |
| `object_lock_configuration` | The Object Lock configuration if enabled | No |
| `logging_configuration` | The logging configuration of the bucket | No |
| `public_access_block_configuration` | The public access block configuration | No |
| `bucket_policy_json` | The JSON policy applied to the bucket | Yes |

## Security Controls Implementation

### 1. Block All Public Access
The module enforces all four public access block settings:
- Block public ACLs
- Block public bucket policies
- Ignore public ACLs
- Restrict public buckets

### 2. Encryption
- **At Rest**: Mandatory SSE-KMS encryption for all objects
- **In Transit**: Bucket policy denies all non-HTTPS requests
- **Bucket Keys**: Automatically enabled for KMS cost optimization

### 3. Access Control
- **IAM-based**: Only specified IAM principals can access the bucket
- **Least Privilege**: Configurable actions per principal
- **Policy Enforcement**: Denies insecure transport and unencrypted uploads

### 4. Versioning
- Enabled by default for all buckets
- Supports recovery from accidental deletion or modification
- Works with lifecycle rules for old version management

### 5. Logging
- Optional server access logging to a separate bucket
- Customizable log prefix for organization
- Helps with compliance auditing and security monitoring

### 6. Object Lock (Bonus)
- Provides WORM (Write Once Read Many) functionality
- Two modes: GOVERNANCE and COMPLIANCE
- Configurable retention period
- Cannot be disabled once enabled

## HIPAA Compliance Considerations

This module implements several HIPAA-required technical safeguards:

1. **Access Control** (§164.312(a)(1)): IAM-based access with least privilege
2. **Audit Controls** (§164.312(b)): Server access logging capability
3. **Integrity** (§164.312(c)(1)): Object versioning and optional Object Lock
4. **Transmission Security** (§164.312(e)(1)): HTTPS-only access enforced
5. **Encryption** (§164.312(a)(2)(iv)): At-rest and in-transit encryption

## Best Practices

1. **KMS encryption is mandatory** for all PHI data
2. **Enable logging** and regularly review access logs
3. **Use Object Lock** for data requiring long-term retention
4. **Implement lifecycle rules** to optimize storage costs
5. **Regularly review and update** trusted principal lists
6. **Use separate buckets** for different data classifications
7. **Enable MFA delete** for additional protection (configure separately)
8. **Monitor bucket metrics** using CloudWatch

## Example Directory Structure

```
.
├── README.md
├── modules/
│   └── s3-phi-bucket/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── examples/
    ├── basic/
    │   └── main.tf
    ├── with-kms/
    │   └── main.tf
    └── with-object-lock/
        └── main.tf
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0

## Testing

See the `examples/` directory for complete examples of module usage. Each example includes:
- Basic configuration
- KMS encryption setup
- Object Lock configuration
- Lifecycle management

## Contributing

When contributing to this module, please ensure:
1. All security controls remain enforced by default
2. New features don't compromise existing security
3. Documentation is updated for any changes
4. Examples are provided for new features

