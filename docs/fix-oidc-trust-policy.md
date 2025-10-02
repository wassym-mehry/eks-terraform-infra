# 🔧 Fix OIDC Trust Policy for GitHub Actions

## Le problème
L'erreur `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity` vient de la trust policy du rôle IAM qui est trop restrictive.

## Solution

### 1. Renouvelle tes credentials AWS
```bash
# Configure tes credentials AWS
aws configure
# ou
aws sso login  # si tu utilises AWS SSO
```

### 2. Applique la trust policy corrigée
```bash
cd /home/wassymmehry/Bureau/eks-terraform-infra
aws iam update-assume-role-policy \
  --role-name GitHubActions-TerraformRole \
  --policy-document file://fix-trust-policy.json
```

### 3. Vérifie que la trust policy est bien appliquée
```bash
aws iam get-role --role-name GitHubActions-TerraformRole --query 'Role.AssumeRolePolicyDocument'
```

Tu dois voir :
```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:wassym-mehry/eks-terraform-infra:*"
}
```

### 4. Test le workflow GitHub Actions
Une fois la trust policy corrigée, relance le workflow **Terraform Destroy** depuis GitHub Actions.

## Différence clé

**AVANT (restrictif) :**
```json
"token.actions.githubusercontent.com:sub": [
  "repo:wassym-mehry/eks-terraform-infra:ref:refs/heads/main",
  "repo:wassym-mehry/eks-terraform-infra:ref:refs/heads/develop",
  "repo:wassym-mehry/eks-terraform-infra:pull_request"
]
```

**APRÈS (permissif) :**
```json
"token.actions.githubusercontent.com:sub": "repo:wassym-mehry/eks-terraform-infra:*"
```

Cela autorise **tous les workflows** de ton repository à utiliser le rôle IAM, y compris :
- Les branches feature/setup-infrastructure
- Les workflow_dispatch (déclenchement manuel)
- Les pull requests
- Etc.

Une fois fait, ton workflow Terraform Destroy devrait fonctionner ! 🚀