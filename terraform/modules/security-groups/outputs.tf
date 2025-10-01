# Security Groups Outputs
output "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_group_security_group_id" {
  description = "Security group ID for EKS node group"
  value       = aws_security_group.node_group.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = var.create_rds_security_group ? aws_security_group.rds[0].id : null
}

output "elasticache_security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = var.create_elasticache_security_group ? aws_security_group.elasticache[0].id : null
}