# Production Environment Configuration
environment = "prod"
aws_region  = "eu-west-1"

# Cluster configuration
cluster_name    = "eks-prod-cluster"
cluster_version = "1.29"

# VPC Configuration
vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]

# Node Group Configuration - High availability for production
node_group_instance_types = ["m5.large", "m5.xlarge"]
node_group_scaling_config = {
  desired_size = 4
  max_size     = 10
  min_size     = 3
}
node_group_capacity_type = "ON_DEMAND" # Stability for production
node_group_disk_size     = 50

# Security Configuration - More restrictive for production
cluster_endpoint_private_access      = true
cluster_endpoint_public_access       = false # Only private access for production
cluster_endpoint_public_access_cidrs = []

# Add-ons Configuration
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler          = true
enable_ebs_csi_driver              = true
enable_efs_csi_driver              = true

# Logging - Full logging for production
enable_cloudwatch_logging = true
cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

# Tags
additional_tags = {
  Purpose     = "Production"
  Team        = "DevOps"
  Backup      = "Critical"
  Monitoring  = "24x7"
  AutoScale   = "Enabled"
  Compliance  = "Required"
}