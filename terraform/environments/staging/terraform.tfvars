# Staging Environment Configuration
environment = "staging"
aws_region  = "eu-west-1"

# Cluster configuration
cluster_name    = "eks-staging-cluster"
cluster_version = "1.29"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

# Node Group Configuration - Balanced for staging
node_group_instance_types = ["t3.large", "t3.xlarge"]
node_group_scaling_config = {
  desired_size = 3
  max_size     = 6
  min_size     = 2
}
node_group_capacity_type = "SPOT" # Cost optimization for staging
node_group_disk_size     = 30

# Security Configuration
cluster_endpoint_private_access      = true
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

# Add-ons Configuration
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler          = true
enable_ebs_csi_driver              = true
enable_efs_csi_driver              = true

# Logging - More comprehensive for staging
enable_cloudwatch_logging = true
cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

# Tags
additional_tags = {
  Purpose     = "Staging"
  Team        = "DevOps"
  Backup      = "Required"
  Monitoring  = "Enabled"
  AutoScale   = "Enabled"
}