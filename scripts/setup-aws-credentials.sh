#!/bin/bash

# Setup AWS Credentials for GitHub Actions
# This script helps you configure OIDC and IAM roles for GitHub Actions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_ORG="your-github-org"
GITHUB_REPO="eks-terraform-infra"
AWS_REGION="eu-west-1"

echo -e "${BLUE}🔧 Setting up AWS credentials for GitHub Actions...${NC}"

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS CLI is installed${NC}"
}

# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is not installed. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ jq is installed${NC}"
}

# Function to get AWS account ID
get_account_id() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS Account ID: ${ACCOUNT_ID}${NC}"
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
                        "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main",
                        "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/develop",
                        "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request"
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
                "dynamodb:*",
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

# Function to create S3 bucket for Terraform state
create_terraform_state_bucket() {
    echo -e "${YELLOW}📝 Creating S3 buckets for Terraform state...${NC}"
    
    ENVIRONMENTS=("dev" "staging" "prod")
    
    for env in "${ENVIRONMENTS[@]}"; do
        BUCKET_NAME="terraform-state-${GITHUB_REPO}-${env}-${ACCOUNT_ID}"
        
        # Create bucket if it doesn't exist
        if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
            aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}
            echo -e "${GREEN}✅ S3 bucket created: ${BUCKET_NAME}${NC}"
            
            # Enable versioning
            aws s3api put-bucket-versioning --bucket ${BUCKET_NAME} --versioning-configuration Status=Enabled
            
            # Enable encryption
            aws s3api put-bucket-encryption --bucket ${BUCKET_NAME} --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
            
            # Block public access
            aws s3api put-public-access-block --bucket ${BUCKET_NAME} --public-access-block-configuration '{
                "BlockPublicAcls": true,
                "IgnorePublicAcls": true,
                "BlockPublicPolicy": true,
                "RestrictPublicBuckets": true
            }'
        else
            echo -e "${GREEN}✅ S3 bucket already exists: ${BUCKET_NAME}${NC}"
        fi
    done
}

# Function to create DynamoDB table for state locking
create_dynamodb_table() {
    echo -e "${YELLOW}📝 Creating DynamoDB tables for Terraform state locking...${NC}"
    
    ENVIRONMENTS=("dev" "staging" "prod")
    
    for env in "${ENVIRONMENTS[@]}"; do
        TABLE_NAME="terraform-state-lock-${env}"
        
        # Check if table exists
        if ! aws dynamodb describe-table --table-name ${TABLE_NAME} >/dev/null 2>&1; then
            aws dynamodb create-table \
                --table-name ${TABLE_NAME} \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region ${AWS_REGION}
            
            echo -e "${GREEN}✅ DynamoDB table created: ${TABLE_NAME}${NC}"
        else
            echo -e "${GREEN}✅ DynamoDB table already exists: ${TABLE_NAME}${NC}"
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
    echo -e "${BLUE}🚀 Starting AWS setup for GitHub Actions...${NC}"
    
    check_aws_cli
    check_jq
    get_account_id
    create_oidc_provider
    create_github_actions_role
    create_terraform_state_bucket
    create_dynamodb_table
    output_configuration
    
    echo -e "${GREEN}✅ Setup completed successfully!${NC}"
}

# Run main function
main "$@"