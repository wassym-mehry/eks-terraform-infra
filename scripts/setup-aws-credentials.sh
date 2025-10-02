#!/bin/bash

# AWS Infrastructure Setup Script for GitHub Actions
# Uses Terraform 1.9.0+ S3 native locking (no DynamoDB required)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
AWS_REGION="eu-west-1"
GITHUB_ORG="wassym-mehry"
GITHUB_REPO="eks-terraform-infra"

echo -e "${BLUE}Starting AWS Infrastructure Setup...${NC}"

# Get AWS Account ID
get_account_id() {
    echo -e "${YELLOW}Getting AWS Account ID...${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}Account ID: ${ACCOUNT_ID}${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}AWS CLI found${NC}"
}

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is not installed. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}jq found${NC}"
}

# Check Terraform version for S3 native locking support
check_terraform_version() {
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed. Please install Terraform 1.9.0+ first.${NC}"
        exit 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r .terraform_version)
    echo -e "${YELLOW}Terraform version: ${TERRAFORM_VERSION}${NC}"
    
    # Simple version check for 1.9.0+
    MAJOR=$(echo ${TERRAFORM_VERSION} | cut -d. -f1)
    MINOR=$(echo ${TERRAFORM_VERSION} | cut -d. -f2)
    
    if [ "$MAJOR" -lt 1 ] || ([ "$MAJOR" -eq 1 ] && [ "$MINOR" -lt 9 ]); then
        echo -e "${RED}Terraform 1.9.0+ required for S3 native locking. Current: ${TERRAFORM_VERSION}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Terraform version supports S3 native locking${NC}"
}

# Function to create OIDC provider
create_oidc_provider() {
    echo -e "${YELLOW}📝 Creating OIDC Identity Provider...${NC}"
    
    # Check if OIDC provider already exists
    OIDC_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)
    
    if [ -z "$OIDC_ARN" ]; then
        # Create OIDC provider
        OIDC_ARN=$(aws iam create-open-id-connect-provider \
            --url https://token.actions.githubusercontent.com \
            --client-id-list sts.amazonaws.com \
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
            --query 'OpenIDConnectProviderArn' --output text)
        echo -e "${GREEN}✅ OIDC Provider created: ${OIDC_ARN}${NC}"
    else
        echo -e "${GREEN}✅ OIDC Provider already exists: ${OIDC_ARN}${NC}"
    fi
}


# Function to create IAM role for GitHub Actions
create_github_actions_role() {
    echo -e "${YELLOW}📝 Creating IAM role for GitHub Actions...${NC}"
    
    ROLE_NAME="GitHubActions-TerraformRole"
    
    # Trust policy for GitHub Actions
    cat > trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "${OIDC_ARN}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
                    ]
                }
            }
        }
    ]
}
EOF

    # Check if role already exists
    if aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Role ${ROLE_NAME} already exists. Updating trust policy...${NC}"
        aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://trust-policy.json
    else
        # Create role
        aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json
        echo -e "${GREEN}✅ IAM Role created: ${ROLE_NAME}${NC}"
    fi
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
    
    # Attach policies
    echo -e "${YELLOW}📝 Attaching policies to role...${NC}"
    
    # Create custom policy for Terraform operations
    cat > terraform-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "eks:*",
                "iam:*",
                "logs:*",
                "kms:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudformation:*",
                "s3:*",
                "sts:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

    # Create or update the policy
    POLICY_NAME="TerraformEKSPolicy"
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    
    if aws iam get-policy --policy-arn $POLICY_ARN >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Policy ${POLICY_NAME} already exists. Creating new version...${NC}"
        aws iam create-policy-version --policy-arn $POLICY_ARN --policy-document file://terraform-policy.json --set-as-default
    else
        aws iam create-policy --policy-name $POLICY_NAME --policy-document file://terraform-policy.json
        echo -e "${GREEN}✅ IAM Policy created: ${POLICY_NAME}${NC}"
    fi
    
    # Attach policy to role
    aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
    echo -e "${GREEN}✅ Policy attached to role${NC}"
    
    # Clean up temp files
    rm -f trust-policy.json terraform-policy.json
}


# Function to create S3 buckets for Terraform state
create_terraform_state_bucket() {
    echo -e "${YELLOW}Creating S3 buckets for Terraform state...${NC}"
    
    ENVIRONMENTS=("dev" "staging" "prod")
    
    for env in "${ENVIRONMENTS[@]}"; do
        BUCKET_NAME="terraform-state-${GITHUB_REPO}-${env}-${ACCOUNT_ID}"
        
        # Check if bucket exists
        if ! aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
            # Create bucket
            aws s3 mb "s3://${BUCKET_NAME}" --region ${AWS_REGION}
            
            # Enable versioning for S3 native locking
            aws s3api put-bucket-versioning \
                --bucket ${BUCKET_NAME} \
                --versioning-configuration Status=Enabled
            
            # Enable server-side encryption
            aws s3api put-bucket-encryption \
                --bucket ${BUCKET_NAME} \
                --server-side-encryption-configuration '{
                    "Rules": [
                        {
                            "ApplyServerSideEncryptionByDefault": {
                                "SSEAlgorithm": "AES256"
                            }
                        }
                    ]
                }'
            
            # Block public access
            aws s3api put-public-access-block \
                --bucket ${BUCKET_NAME} \
                --public-access-block-configuration '{
                    "BlockPublicAcls": true,
                    "IgnorePublicAcls": true,
                    "BlockPublicPolicy": true,
                    "RestrictPublicBuckets": true
                }'
            
            echo -e "${GREEN}[OK] S3 bucket created: ${BUCKET_NAME}${NC}"
        else
            echo -e "${GREEN}[OK] S3 bucket already exists: ${BUCKET_NAME}${NC}"
        fi
    done
}

# Function to output configuration
output_configuration() {
    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo -e "${GREEN}OIDC Provider ARN: ${OIDC_ARN}${NC}"
    echo -e "${GREEN}GitHub Actions Role ARN: ${ROLE_ARN}${NC}"
    echo ""
    echo -e "${YELLOW}🔑 Add this secret to your GitHub repository:${NC}"
    echo -e "${GREEN}AWS_ROLE_TO_ASSUME=${ROLE_ARN}${NC}"
    echo ""
    echo -e "${YELLOW}📝 Update the backend.conf files with these bucket names:${NC}"
    for env in dev staging prod; do
        echo -e "${GREEN}${env}: terraform-state-${GITHUB_REPO}-${env}-${ACCOUNT_ID}${NC}"
    done
}

# Main execution
main() {
    echo -e "${BLUE}Starting AWS setup for S3 native locking...${NC}"
    
    check_aws_cli
    check_jq
    check_terraform_version
    get_account_id
    create_oidc_provider
    create_github_actions_role
    create_terraform_state_bucket
    output_configuration
    echo ""
    echo -e "${GREEN}[SUCCESS] Setup completed successfully!${NC}"
}

# Run main function
main "$@"
