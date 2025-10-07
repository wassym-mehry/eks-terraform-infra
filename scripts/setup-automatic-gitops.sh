#!/bin/bash

# Script de configuration complète du workflow GitOps automatique
# Usage: ./setup-automatic-gitops.sh

set -e

echo "🚀 Configuration du Workflow GitOps Automatique"
echo "=============================================="

# 1. Exécuter le script de création du rôle IAM
echo "📝 Étape 1: Création du rôle IAM ECR..."
chmod +x ./create-github-ecr-role.sh
./create-github-ecr-role.sh

# 2. Récupérer les informations AWS
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-1"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/github-actions-ecr-fenwave"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo ""
echo "📋 Configuration GitHub Secrets"
echo "==============================="
echo ""
echo "🔑 Secrets à configurer dans GitHub Repository:"
echo "Repository: https://github.com/Fenleap/Fenwave-backstage"
echo "Path: Settings → Secrets and variables → Actions"
echo ""
echo "Ajoutez ces secrets:"
echo "AWS_ROLE_TO_ASSUME: $ROLE_ARN"
echo "GITOPS_TOKEN: <votre-github-token>"
echo ""
echo "Variables d'environnement (optionnel):"
echo "ECR_REGISTRY: $ECR_REGISTRY"
echo "AWS_REGION: $REGION"

echo ""
echo "🔧 Configuration ArgoCD"
echo "======================"
echo ""
echo "1. Démarrez ArgoCD:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo ""
echo "2. Vérifiez que l'application 'fenwave-idp' est configurée avec:"
echo "   - Auto-Sync: Enabled"
echo "   - Self-Heal: Enabled"
echo "   - Prune: Enabled"

echo ""
echo "📊 Test du Workflow"
echo "=================="
echo ""
echo "Pour tester le workflow complet:"
echo "1. Modifiez du code dans: https://github.com/Fenleap/Fenwave-backstage"
echo "2. Committez sur une branche 'feature/' ou 'release/'"
echo "3. Observez GitHub Actions build et push l'image"
echo "4. Vérifiez que le manifest GitOps est mis à jour automatiquement"
echo "5. Confirmez qu'ArgoCD sync automatiquement le nouveau deployment"

echo ""
echo "🎯 Workflow Final"
echo "================"
echo "Code Change → Push → GitHub Actions → ECR → GitOps Update → ArgoCD Sync → Cluster"

echo ""
echo "✅ Configuration terminée!"
echo ""
echo "🔗 Liens utiles:"
echo "- ArgoCD: http://localhost:8080 (après port-forward)"
echo "- Backstage: http://localhost:3000 (après port-forward)" 
echo "- ECR Repository: https://console.aws.amazon.com/ecr/repositories/private/${ACCOUNT_ID}/fenwave/idp"
echo "- GitHub Actions: https://github.com/Fenleap/Fenwave-backstage/actions"

echo ""
echo "📝 Prochaines étapes:"
echo "1. Configurez les secrets GitHub mentionnés ci-dessus"
echo "2. Copiez le workflow dans .github/workflows/build-push-ecr.yml"
echo "3. Testez avec un commit de test"