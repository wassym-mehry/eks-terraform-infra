#!/bin/bash

# Configuration ArgoCD pour auto-sync complet
# Usage: ./configure-argocd-autosync.sh

set -e

echo "🔧 Configuration ArgoCD Auto-Sync"

# Patcher l'application pour activer l'auto-sync complet
kubectl patch application fenwave-idp -n argocd --type merge -p '{
  "spec": {
    "syncPolicy": {
      "automated": {
        "prune": true,
        "selfHeal": true,
        "allowEmpty": false
      },
      "syncOptions": [
        "CreateNamespace=true",
        "PrunePropagationPolicy=foreground",
        "PruneLast=true"
      ],
      "retry": {
        "limit": 5,
        "backoff": {
          "duration": "5s",
          "factor": 2,
          "maxDuration": "3m"
        }
      }
    }
  }
}'

echo "✅ ArgoCD configuré pour auto-sync complet"

# Vérifier la configuration
echo "📊 Statut de l'application:"
kubectl get application fenwave-idp -n argocd -o jsonpath='{.spec.syncPolicy}' | jq .

echo ""
echo "🔄 ArgoCD va maintenant:"
echo "- ✅ Synchroniser automatiquement les changements"
echo "- ✅ Supprimer les ressources obsolètes (prune)"
echo "- ✅ Corriger automatiquement les dérives (self-heal)"
echo "- ✅ Réessayer en cas d'échec"