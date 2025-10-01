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
    echo ""
    echo -e "${BLUE}=== Configuration Summary ===${NC}"
    echo ""
    echo -e "${YELLOW}Update the backend.conf files with these bucket names:${NC}"
    for env in dev staging prod; do
        echo -e "${GREEN}${env}: terraform-state-${GITHUB_REPO}-${env}-${ACCOUNT_ID}${NC}"
    done
    echo ""
    echo -e "${BLUE}S3 Native Locking Configuration:${NC}"
    echo -e "${GREEN}[OK] S3 Native Locking: Enabled (use_lockfile = true)${NC}"
    echo -e "${GREEN}[OK] DynamoDB: Not required (cost savings!)${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "${YELLOW}1. Update backend.conf files with the bucket names above${NC}"
    echo -e "${YELLOW}2. Ensure Terraform 1.9.0+ is installed${NC}"
    echo -e "${YELLOW}3. Test with: make init ENV=dev${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting AWS setup for S3 native locking...${NC}"
    
    check_aws_cli
    check_jq
    check_terraform_version
    get_account_id
    create_terraform_state_bucket
    output_configuration
    
    echo ""
    echo -e "${GREEN}[SUCCESS] Setup completed successfully!${NC}"
    echo -e "${BLUE}Cost savings: No DynamoDB tables needed with S3 native locking!${NC}"
}

# Run main function
main "$@"
