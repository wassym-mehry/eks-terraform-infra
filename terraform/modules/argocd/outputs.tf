output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = var.argocd_admin_password
  sensitive   = true
}