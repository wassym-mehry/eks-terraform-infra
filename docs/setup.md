# Setup Guide - EKS Terraform Infrastructure

This guide will walk you through setting up the complete EKS infrastructure with Terraform and GitHub Actions.

## 📋 Prerequisites

### Tools Required
- **AWS CLI** (v2.x or later)
- **Terraform** (v1.6.0 or later)
- **kubectl** (latest version)
- **Git**
- **jq** (for JSON processing)

### AWS Account Requirements
- AWS Account with administrative privileges
- AWS CLI configured with appropriate credentials
- Sufficient permissions to create:
  - EKS clusters
  - VPC and networking resources
  - IAM roles and policies
  - EC2 instances
  - S3 buckets
  - DynamoDB tables

## 🚀 Step-by-Step Setup

### Step 1: Clone and Prepare Repository

```bash
# Clone the repository
git clone <your-repo-url>
cd eks-terraform-infra

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 2: Configure AWS Credentials for GitHub Actions

This project uses OpenID Connect (OIDC) for secure authentication between GitHub Actions and AWS.

```bash
# Run the setup script
./scripts/setup-aws-credentials.sh
```

This script will:
- Create an OIDC identity provider in AWS
- Create an IAM role for GitHub Actions
- Create S3 buckets for Terraform state
- Create DynamoDB tables for state locking
- Output the configuration needed for GitHub

### Step 3: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Add the following repository secret:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::ACCOUNT-ID:role/GitHubActions-TerraformRole` | IAM role ARN for GitHub Actions |

### Step 4: Update Backend Configuration

Update the backend configuration files with your actual S3 bucket names:

```bash
# Update terraform/environments/dev/backend.conf
# Update terraform/environments/staging/backend.conf
# Update terraform/environments/prod/backend.conf
```

Replace the bucket names with the ones created by the setup script:
- `terraform-state-eks-terraform-infra-dev-ACCOUNT-ID`
- `terraform-state-eks-terraform-infra-staging-ACCOUNT-ID`
- `terraform-state-eks-terraform-infra-prod-ACCOUNT-ID`

### Step 5: Customize Environment Variables

Edit the environment-specific configuration files:

**Development Environment:**
```bash
# terraform/environments/dev/terraform.tfvars
# Adjust values according to your needs
```

**Staging Environment:**
```bash
# terraform/environments/staging/terraform.tfvars
# Configure for staging requirements
```

**Production Environment:**
```bash
# terraform/environments/prod/terraform.tfvars
# Configure for production requirements
```

### Step 6: Test Local Deployment (Optional)

Before using GitHub Actions, you can test locally:

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform for dev environment
terraform init -backend-config="environments/dev/backend.conf"

# Plan the deployment
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply (only if you want to test locally)
# terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Step 7: Deploy via GitHub Actions

1. **Create a Pull Request:**
   ```bash
   git checkout -b feature/setup-infrastructure
   git add .
   git commit -m "Initial EKS infrastructure setup"
   git push origin feature/setup-infrastructure
   ```

2. **Review the Plan:**
   - Create a PR to `main` or `develop`
   - GitHub Actions will automatically run `terraform plan`
   - Review the plan output in the PR comments

3. **Deploy to Development:**
   - Merge the PR to trigger automatic deployment to `dev`
   - Monitor the GitHub Actions workflow

4. **Deploy to Staging/Production:**
   - Use the manual workflow dispatch for controlled deployments
   - Go to **Actions** → **Terraform Apply** → **Run workflow**
   - Select the environment and confirm with "apply"

## 🔧 Post-Deployment Configuration

### Connect to Your EKS Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name <cluster-name>

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Install Additional Tools (Optional)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify AWS Load Balancer Controller is running
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Verify Cluster Autoscaler is running
kubectl get pods -n kube-system | grep cluster-autoscaler
```

## 🔍 Monitoring and Verification

### Check Infrastructure Status

```bash
# List EKS clusters
aws eks list-clusters --region eu-west-1

# Check node group status
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name> --region eu-west-1

# Verify VPC and subnets
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=eks-infrastructure"
```

### View Terraform State

```bash
# Check current state
terraform show

# List resources
terraform state list

# Get specific outputs
terraform output cluster_endpoint
terraform output configure_kubectl
```

## 🚨 Troubleshooting

### Common Issues

1. **OIDC Provider Issues:**
   ```bash
   # Verify OIDC provider exists
   aws iam list-open-id-connect-providers
   ```

2. **Permission Issues:**
   ```bash
   # Check current AWS identity
   aws sts get-caller-identity
   
   # Verify role can be assumed
   aws sts assume-role --role-arn <role-arn> --role-session-name test
   ```

3. **State Lock Issues:**
   ```bash
   # If state is locked, force unlock (use carefully!)
   terraform force-unlock <lock-id>
   ```

4. **Node Group Issues:**
   ```bash
   # Check node group logs
   aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
   
   # Check EC2 instances
   aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=<cluster-name>"
   ```

### Debugging Steps

1. **Check GitHub Actions Logs:**
   - Go to Actions tab in your GitHub repository
   - Click on the failed workflow
   - Review the detailed logs

2. **Validate Terraform Configuration:**
   ```bash
   # Validate syntax
   terraform validate
   
   # Format code
   terraform fmt -recursive
   ```

3. **AWS CloudTrail:**
   - Check AWS CloudTrail for API call logs
   - Look for permission denied errors

## 🧹 Cleanup

To destroy the infrastructure:

1. **Using GitHub Actions:**
   - Go to **Actions** → **Terraform Destroy**
   - Select environment
   - Type "destroy" and environment name to confirm

2. **Manual Cleanup:**
   ```bash
   # Run cleanup script to check for orphaned resources
   ./scripts/cleanup.sh
   ```

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review AWS CloudTrail logs
3. Check GitHub Actions workflow logs
4. Verify all prerequisites are met

## 🔐 Security Considerations

- Always use least-privilege IAM policies
- Regularly rotate access keys
- Monitor CloudTrail logs
- Keep Terraform and tools updated
- Use private subnets for worker nodes
- Enable VPC Flow Logs
- Regular security audits