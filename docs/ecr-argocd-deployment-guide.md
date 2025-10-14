# Guide de Déploiement ECR et ArgoCD pour Fenwave

Ce guide détaille l'implémentation de la pipeline CI/CD avec ECR et ArgoCD pour le projet Fenwave.

## 🏗️ Architecture Implémentée

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Fenwave IDP   │ -> │ GitHub Actions│ -> │  Amazon ECR     │
│   (Backstage)   │    │   CI/CD       │    │  (Container     │
└─────────────────┘    └──────────────┘    │   Registry)     │
                                           └─────────────────┘
                                                    │
                                                    │ Pull Images
                                                    ▼
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   EKS Cluster   │ <- │    ArgoCD     │ <- │   GitOps Repo   │
│   (Runtime)     │    │  (Deployment) │    │  (Manifests)    │
└─────────────────┘    └──────────────┘    └─────────────────┘
```

## 📋 Prérequis

1. **AWS CLI** configuré avec les bonnes permissions
2. **Terraform** v1.0+
3. **kubectl** installé
4. **Docker** installé
5. **Yarn** pour le projet Backstage

## 🚀 Étapes de Déploiement

### 1. Déploiement de l'Infrastructure Terraform

```bash
cd eks-terraform-infra/terraform

# Initialiser Terraform
terraform init -backend-config=environments/dev/backend.conf

# Planifier le déploiement
terraform plan -var-file=environments/dev/terraform.tfvars

# Appliquer les changements
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 2. Configuration de kubectl

```bash
# Récupérer la configuration du cluster
aws eks update-kubeconfig --region eu-west-1 --name fenwave-dev-eks
```

### 3. Vérification d'ArgoCD

```bash
# Vérifier que ArgoCD est déployé
kubectl get pods -n argocd

# Récupérer le mot de passe admin d'ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward pour accéder à ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Accédez à ArgoCD sur https://localhost:8080

### 4. Configuration des Secrets GitHub

Dans GitHub, ajoutez les secrets suivants :

```
AWS_ROLE_TO_ASSUME: arn:aws:iam::ACCOUNT_ID:role/fenwave-dev-github-actions-role
```

### 5. Build et Push de la Première Image

```bash
cd Fenwave-backstage

# Build et push manuel
./build-push-image.sh v1.0.0 dev

# Ou déclencher via GitHub Actions en pushant sur develop
git add .
git commit -m "feat: setup ECR and ArgoCD integration"
git push origin develop
```

## 📁 Structure des Fichiers Créés/Modifiés

### Infrastructure Terraform

```
eks-terraform-infra/
├── terraform/
│   ├── modules/
│   │   ├── ecr/
│   │   │   ├── main.tf          # ECR repository et policies
│   │   │   ├── variables.tf     # Variables ECR
│   │   │   └── outputs.tf       # Outputs ECR
│   │   └── argocd/
│   │       ├── main.tf          # Installation ArgoCD via Helm
│   │       ├── variables.tf     # Variables ArgoCD
│   │       ├── outputs.tf       # Outputs ArgoCD
│   │       ├── providers.tf     # Providers requis
│   │       └── configs/
│   │           ├── argocd-values.yaml      # Configuration ArgoCD
│   │           └── fenwave-application.yaml # Application Fenwave
│   ├── main.tf              # Module calls mis à jour
│   ├── variables.tf         # Variables ajoutées pour ECR/ArgoCD
│   ├── outputs.tf           # Outputs ajoutés
│   └── providers.tf         # Provider kubectl ajouté
```

### GitOps Manifests

```
eks-terraform-infra/
└── gitops/
    └── applications/
        └── fenwave-idp/
            ├── base/
            │   ├── deployment.yaml
            │   └── kustomization.yaml
            ├── dev/
            │   ├── kustomization.yaml
            │   └── deployment-dev.yaml
            └── prod/
                ├── kustomization.yaml
                └── deployment-prod.yaml
```

### CI/CD Pipeline

```
Fenwave-backstage/
├── .github/
│   └── workflows/
│       └── build-push-ecr.yml   # Pipeline automatisée
└── build-push-image.sh          # Script amélioré
```

## 🔄 Workflow CI/CD

### 1. Déclencheurs

- **Push sur `main`** : Déploie en production
- **Push sur `develop`** : Déploie en développement
- **Pull Request** : Build de validation
- **Tags** : Releases versionnées

### 2. Pipeline Automatique

1. **Build** : Compilation TypeScript + Build Backend
2. **Docker Build** : Création de l'image multi-plateforme
3. **ECR Push** : Push vers Amazon ECR
4. **GitOps Update** : Mise à jour automatique des manifests
5. **ArgoCD Sync** : Déploiement automatique sur EKS

### 3. Environnements

- **dev** : Images `dev-<commit-hash>`
- **prod** : Images `prod-<commit-hash>` + `latest`

## 🛠️ Commandes Utiles

### Monitoring ArgoCD

```bash
# Voir les applications ArgoCD
kubectl get applications -n argocd

# Voir les logs d'ArgoCD
kubectl logs -n argocd deployment/argocd-application-controller

# Synchroniser manuellement une application
argocd app sync fenwave-idp
```

### Debug ECR

```bash
# Lister les images dans ECR
aws ecr describe-images --repository-name fenwave/idp --region eu-west-1

# Login manuel à ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 752566893537.dkr.ecr.eu-west-1.amazonaws.com
```

### Debug Kubernetes

```bash
# Voir les pods Fenwave
kubectl get pods -n fenwave

# Voir les logs de l'application
kubectl logs -n fenwave deployment/fenwave-idp

# Describe un pod pour debug
kubectl describe pod -n fenwave <pod-name>
```

## 🔒 Sécurité

### 1. IAM Roles

- **GitHub Actions Role** : Permissions limitées pour push ECR
- **ArgoCD Role** : Permissions limitées pour pull ECR
- **Node Group Role** : Permissions ECR en lecture seule

### 2. ECR Policies

- **Lifecycle Policy** : Nettoyage automatique des anciennes images
- **Repository Policy** : Accès contrôlé par rôles IAM

### 3. Network Security

- **Security Groups** : Accès limité aux ports nécessaires
- **Private Subnets** : Nodes dans des subnets privés
- **VPC Endpoints** : Communications sécurisées avec AWS services

## 🚨 Troubleshooting

### Problèmes Courants

1. **ArgoCD ne peut pas puller l'image**
   ```bash
   # Vérifier le service account
   kubectl describe sa argocd-repo-server -n argocd
   ```

2. **GitHub Actions échoue sur ECR push**
   ```bash
   # Vérifier le rôle IAM
   aws sts get-caller-identity
   ```

3. **Application ne démarre pas**
   ```bash
   # Vérifier les logs
   kubectl logs -n fenwave deployment/fenwave-idp --previous
   ```

## 📈 Monitoring et Observabilité

### Métriques à Surveiller

- **ECR** : Utilisation du storage, fréquence des pushes
- **ArgoCD** : Statut des synchronisations, délais de déploiement
- **Kubernetes** : Utilisation des ressources, santé des pods

### Alertes Recommandées

- Échec de synchronisation ArgoCD
- Images ECR non utilisées depuis >30 jours
- Pods en état `CrashLoopBackOff`

## 🔄 Prochaines Étapes

1. **Monitoring** : Implémenter Prometheus + Grafana
2. **Ingress** : Configurer un ingress controller pour exposer Fenwave
3. **SSL** : Ajouter des certificats SSL via cert-manager
4. **Backup** : Configurer la sauvegarde des données persistantes
5. **Multi-env** : Étendre à staging et production

## 📚 Ressources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Backstage Documentation](https://backstage.io/docs/)