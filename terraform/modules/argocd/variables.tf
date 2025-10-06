variable "argocd_namespace" {
  description = "Namespace for ArgoCD installation"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for GitOps"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "enable_load_balancer" {
  description = "Enable load balancer for ArgoCD"
  type        = bool
  default     = false
}

variable "argocd_admin_password" {
  description = "Admin password for ArgoCD"
  type        = string
  sensitive   = true
}

variable "argocd_ecr_role_arn" {
  description = "IAM role ARN for ArgoCD to access ECR"
  type        = string
}

variable "create_fenwave_application" {
  description = "Create ArgoCD application for Fenwave"
  type        = bool
  default     = true
}

variable "fenwave_namespace" {
  description = "Namespace for Fenwave application"
  type        = string
  default     = "fenwave"
}

variable "enable_ingress" {
  description = "Enable ingress for ArgoCD"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of SSL certificate for ArgoCD ingress"
  type        = string
  default     = ""
}