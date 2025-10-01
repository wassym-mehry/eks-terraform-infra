# Migration Guide: DynamoDB to S3 Native Locking

This guide helps you migrate from DynamoDB-based state locking to Terraform's new S3 native locking feature (available in Terraform 1.9.0+).

## 🎯 Why Migrate to S3 Native Locking?

### Benefits
- ✅ **Simplified Infrastructure**: No need to manage DynamoDB tables
- ✅ **Cost Reduction**: Eliminates DynamoDB costs for state locking
- ✅ **Better Performance**: Native S3 locking is faster and more reliable
- ✅ **Less Complexity**: One less AWS service to monitor and maintain
- ✅ **Built-in Terraform Support**: No external dependencies

### Comparison

| Feature | DynamoDB Locking | S3 Native Locking |
|---------|------------------|-------------------|
| **Setup Complexity** | High (separate table per environment) | Low (built into S3 bucket) |
| **Cost** | ~$2.50/month per table | Included with S3 |
| **Performance** | Good | Better |
| **Maintenance** | Manual table management | Automatic |
| **Terraform Version** | All versions | 1.9.0+ |

## 🚀 Migration Steps

### Step 1: Prerequisites Check

```bash
# Check Terraform version
make check-s3-locking ENV=dev

# Should show Terraform 1.9.0+ for S3 native locking support
```

### Step 2: Update Backend Configuration

Update your backend configuration files to use S3 native locking:

**Before (DynamoDB locking):**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-dev"
    key            = "eks-infra/dev/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-dev"  # DynamoDB locking
  }
}
```

**After (S3 native locking):**
```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket-dev"
    key          = "eks-infra/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true  # S3 native locking
    
    # Optional: Keep DynamoDB for redundancy
    # dynamodb_table = "terraform-state-lock-dev"
  }
}
```

### Step 3: Enable S3 Bucket Versioning

S3 native locking requires versioning to be enabled:

```bash
# Enable versioning for existing buckets
aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket-dev \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket-staging \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket-prod \
  --versioning-configuration Status=Enabled
```

### Step 4: Update Terraform Configuration

Update your backend configuration files:

```bash
# Update dev environment
# Edit terraform/environments/dev/backend.conf
bucket       = "your-terraform-state-bucket-dev"
key          = "eks-infra/dev/terraform.tfstate"
region       = "eu-west-1"
encrypt      = true
use_lockfile = true

# Repeat for staging and prod environments
```

### Step 5: Reinitialize Terraform

For each environment, reinitialize Terraform to use the new locking:

```bash
# Development
make init ENV=dev

# Staging
make init ENV=staging

# Production  
make init ENV=prod
```

### Step 6: Test the Migration

Test that S3 native locking works:

```bash
# Test with a plan
make plan ENV=dev

# Check for any lock-related errors
# Should complete without DynamoDB-related errors
```

### Step 7: Verify Lock Files

Check that S3 lock files are created:

```bash
# List lock files in S3
aws s3 ls s3://your-terraform-state-bucket-dev/eks-infra/dev/ --recursive | grep .tflock
```

## 🔄 Rollback Plan

If you need to rollback to DynamoDB locking:

### Step 1: Revert Backend Configuration
```bash
# Remove use_lockfile and add back dynamodb_table
# In terraform/environments/*/backend.conf:
dynamodb_table = "terraform-state-lock-dev"
# Remove: use_lockfile = true
```

### Step 2: Reinitialize
```bash
make init ENV=dev
```

## 🧹 Cleanup DynamoDB Tables (Optional)

After successful migration and testing, you can optionally remove DynamoDB tables:

⚠️ **Warning**: Only do this after confirming S3 native locking works correctly!

```bash
# List existing DynamoDB tables
aws dynamodb list-tables --query 'TableNames[?contains(@, `terraform-state-lock`)]'

# Delete tables (BE CAREFUL!)
aws dynamodb delete-table --table-name terraform-state-lock-dev
aws dynamodb delete-table --table-name terraform-state-lock-staging
aws dynamodb delete-table --table-name terraform-state-lock-prod
```

## 🔒 Hybrid Approach (Recommended for Production)

For critical production environments, you can use both locking mechanisms for redundancy:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-prod"
    key            = "eks-infra/prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    use_lockfile   = true                        # S3 native locking
    dynamodb_table = "terraform-state-lock-prod" # DynamoDB backup locking
  }
}
```

With this configuration:
- Terraform must acquire locks from **both** S3 and DynamoDB
- Provides maximum protection against concurrent operations
- Higher cost but maximum reliability

## 🚨 Troubleshooting

### Issue: "use_lockfile not supported"
**Solution**: Upgrade Terraform to 1.9.0 or later
```bash
# Check version
terraform version

# Upgrade if needed
make install-tools
```

### Issue: "S3 bucket versioning not enabled"
**Solution**: Enable versioning on the S3 bucket
```bash
aws s3api put-bucket-versioning \
  --bucket your-bucket-name \
  --versioning-configuration Status=Enabled
```

### Issue: "Permission denied on S3 lock files"
**Solution**: Ensure IAM role has S3 permissions for lock files
```json
{
    "Effect": "Allow",
    "Action": [
        "s3:GetObject*",
        "s3:PutObject*",
        "s3:DeleteObject*"
    ],
    "Resource": "arn:aws:s3:::your-bucket/*"
}
```

### Issue: "Lock file conflicts"
**Solution**: Clean up stale lock files
```bash
# List lock files
aws s3 ls s3://your-bucket/path/ --recursive | grep .tflock

# Remove stale lock files (BE CAREFUL!)
aws s3 rm s3://your-bucket/path/to/stale.tflock
```

## 📊 Cost Impact

### Before (DynamoDB Locking)
- **DynamoDB**: ~$2.50/month per table
- **3 Environments**: ~$7.50/month
- **S3**: Normal storage costs

### After (S3 Native Locking)
- **DynamoDB**: $0 (eliminated)
- **S3**: Normal storage costs + minimal lock file overhead
- **Total Savings**: ~$7.50/month

## ✅ Migration Checklist

- [ ] Terraform version 1.9.0+ installed
- [ ] S3 bucket versioning enabled
- [ ] Backend configuration updated with `use_lockfile = true`
- [ ] Terraform reinitialized for all environments
- [ ] Migration tested with terraform plan/apply
- [ ] Lock files verified in S3
- [ ] Team notified of migration
- [ ] Documentation updated
- [ ] DynamoDB tables deleted (optional, after testing period)

## 🎯 Next Steps

After successful migration:

1. **Monitor**: Watch for any lock-related issues for 1-2 weeks
2. **Clean up**: Remove DynamoDB tables if no longer needed
3. **Update CI/CD**: Ensure all automation uses new locking
4. **Document**: Update team procedures and runbooks
5. **Share**: Share migration experience with team