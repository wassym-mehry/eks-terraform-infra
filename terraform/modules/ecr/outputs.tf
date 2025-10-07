output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.fenwave_idp.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.fenwave_idp.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.fenwave_idp.name
}