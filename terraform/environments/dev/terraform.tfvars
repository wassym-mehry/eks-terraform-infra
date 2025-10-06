# Development Environment Configuration
environment = "dev"
aws_region  = "eu-west-1"

# Cluster configuration
cluster_name    = "eks-dev-cluster"
cluster_version = "1.29"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.4.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# Node Group Configuration - Optimized for development
node_group_instance_types = ["t3.medium"]
node_group_scaling_config = {
  desired_size = 2
  max_size     = 3
  min_size     = 1
}
node_group_capacity_type = "ON_DEMAND"
node_group_disk_size     = 20

# Security Configuration
cluster_endpoint_private_access      = true
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Restrict this in production

# Add-ons Configuration
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler          = true
enable_ebs_csi_driver              = true
enable_efs_csi_driver              = false

# Logging
enable_cloudwatch_logging = true
cluster_enabled_log_types = ["audit", "api", "authenticator"]

# Tags
additional_tags = {
  Purpose     = "Development"
  Team        = "DevOps"
  Backup      = "Required"
  Monitoring  = "Enabled"
}