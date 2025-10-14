# IAM Module Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
}

variable "enable_ebs_csi_driver" {
  description = "Enable Amazon EBS CSI driver"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
  default     = ""
}