# Backend configuration for Terraform state
# Using S3 native locking (Terraform 1.9.0+) - No DynamoDB required
terraform {
  backend "s3" {
    # Ces valeurs seront définies via les arguments -backend-config
    # ou les variables d'environnement dans GitHub Actions
    
    # bucket       = "your-terraform-state-bucket"
    # key          = "eks-infra/terraform.tfstate"
    # region       = "eu-west-1"
    # encrypt      = true
    use_lockfile = true  # S3 native locking (Terraform 1.9.0+)
  }
}

# Alternative: Configuration backend locale pour le développement
# Décommentez si vous voulez utiliser un backend local
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }