# EKS Terraform Infrastructure

This project automates the deployment of an Amazon EKS cluster using Terraform and GitHub Actions.

## 📁 Project Structure

```
eks-terraform-infra/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       └── terraform-destroy.yml
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── security-groups/
│   │   └── iam/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── backend.tf
├── scripts/
│   ├── setup-aws-credentials.sh
│   └── cleanup.sh
└── docs/
    ├── setup.md
    └── troubleshooting.md
```

## 🚀 Quick Start

1. Configure AWS credentials in GitHub Secrets
2. Update environment-specific variables in `terraform/environments/`
3. Push to trigger GitHub Actions workflow

## 📋 Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- Terraform 1.9.0+ (for S3 native locking support)
- AWS CLI v2+

## 🔧 Configuration

See [docs/setup.md](docs/setup.md) for detailed setup instructions.