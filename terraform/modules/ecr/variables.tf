variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  type        = string
}

variable "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  type        = string
}