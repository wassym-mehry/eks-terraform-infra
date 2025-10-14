# IAM Outputs
output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.node_group.arn
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC Provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC Provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "argocd_ecr_role_arn" {
  description = "ARN of the ArgoCD ECR IAM role"
  value       = aws_iam_role.argocd_ecr.arn
}