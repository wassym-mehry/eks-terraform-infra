#!/bin/bash

# Script pour créer un rôle IAM pour GitHub Actions avec accès ECR
# Usage: ./create-github-ecr-role.sh

set -e

# Variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-1"
ROLE_NAME="github-actions-ecr-fenwave"
POLICY_NAME="ECRPushPolicy"
REPOSITORY_NAME="eks-infrastructure/idp"

echo "🚀 Création du rôle IAM pour GitHub Actions ECR Access"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Role Name: $ROLE_NAME"

# 1. Créer la politique de confiance pour GitHub Actions
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:Fenleap/Fenwave-backstage:*"
                    ]
                }
            }
        }
    ]
}
EOF

# 2. Créer la politique IAM pour ECR
cat > ecr-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:GetLifecyclePolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:ListTagsForResource",
                "ecr:DescribeImageScanFindings"
            ],
            "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/${REPOSITORY_NAME}"
        }
    ]
}
EOF

# 3. Vérifier si le provider OIDC existe
echo "🔍 Vérification du provider OIDC GitHub..."
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" >/dev/null 2>&1; then
    echo "📝 Création du provider OIDC GitHub Actions..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        --client-id-list sts.amazonaws.com
    echo "✅ Provider OIDC créé"
else
    echo "✅ Provider OIDC existe déjà"
fi

# 4. Créer la politique IAM
echo "📝 Création de la politique IAM..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://ecr-policy.json \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
    aws iam get-policy \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
    --query 'Policy.Arn' \
    --output text)

echo "✅ Politique créée/récupérée: $POLICY_ARN"

# 5. Créer le rôle IAM
echo "📝 Création du rôle IAM..."
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "Rôle pour GitHub Actions - ECR Push Fenwave" || echo "⚠️  Rôle existe déjà"

# 6. Attacher la politique au rôle
echo "🔗 Attachement de la politique au rôle..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN

# 7. Créer le repository ECR s'il n'existe pas
echo "📝 Vérification/Création du repository ECR..."
if ! aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION >/dev/null 2>&1; then
    aws ecr create-repository \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true
    echo "✅ Repository ECR créé: $REPOSITORY_NAME"
else
    echo "✅ Repository ECR existe déjà: $REPOSITORY_NAME"
fi

# 8. Afficher les informations importantes
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
ECR_REPOSITORY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}"

echo ""
echo "🎉 Configuration terminée!"
echo ""
echo "📋 Informations à configurer dans GitHub:"
echo "Repository: https://github.com/Fenleap/Fenwave-backstage"
echo "Settings → Secrets and variables → Actions"
echo ""
echo "Secrets à ajouter:"
echo "AWS_ROLE_TO_ASSUME: $ROLE_ARN"
echo "ECR_REGISTRY: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo "ECR_REPOSITORY: $REPOSITORY_NAME"
echo "AWS_REGION: $REGION"
echo ""
echo "🔧 Repository ECR: $ECR_REPOSITORY"

# Nettoyage
rm -f trust-policy.json ecr-policy.json

echo "✅ Script terminé avec succès!"