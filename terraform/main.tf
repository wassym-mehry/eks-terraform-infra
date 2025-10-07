# Local values for common tags
locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    },
    var.additional_tags
  )

  cluster_name = "${var.project_name}-${var.environment}-eks"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = local.cluster_name
  common_tags          = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id                                = module.vpc.vpc_id
  project_name                          = var.project_name
  environment                           = var.environment
  cluster_endpoint_public_access_cidrs  = var.cluster_endpoint_public_access_cidrs
  create_rds_security_group             = false
  create_elasticache_security_group     = false
  common_tags                           = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name                        = var.project_name
  environment                         = var.environment
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  enable_ebs_csi_driver              = var.enable_ebs_csi_driver
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_cluster_autoscaler          = var.enable_cluster_autoscaler
  github_org                         = var.github_org
  github_repo                        = var.github_repo
  ecr_repository_arn                 = module.ecr.repository_arn
  common_tags                        = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name                          = local.cluster_name
  cluster_version                       = var.cluster_version
  cluster_role_arn                      = module.iam.cluster_role_arn
  node_group_role_arn                   = module.iam.node_group_role_arn
  private_subnet_ids                    = module.vpc.private_subnet_ids
  public_subnet_ids                     = module.vpc.public_subnet_ids
  cluster_security_group_id             = module.security_groups.cluster_security_group_id
  node_group_security_group_id          = module.security_groups.node_group_security_group_id
  cluster_endpoint_private_access       = var.cluster_endpoint_private_access
  cluster_endpoint_public_access        = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs  = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types             = var.cluster_enabled_log_types
  enable_cluster_encryption             = var.enable_cluster_encryption
  project_name                          = var.project_name
  environment                           = var.environment
  node_group_instance_types             = var.node_group_instance_types
  node_group_scaling_config             = var.node_group_scaling_config
  node_group_disk_size                  = var.node_group_disk_size
  node_group_ami_type                   = var.node_group_ami_type
  node_group_capacity_type              = var.node_group_capacity_type
  cloudwatch_log_retention_days         = 14
  common_tags                           = local.common_tags

  cluster_addons = {
    coredns = {
      version                  = "v1.11.1-eksbuild.4"
      service_account_role_arn = null
    }
    kube-proxy = {
      version                  = "v1.29.0-eksbuild.1"
      service_account_role_arn = null
    }
    vpc-cni = {
      version                  = "v1.16.0-eksbuild.1"
      service_account_role_arn = null
    }
    aws-ebs-csi-driver = var.enable_ebs_csi_driver ? {
      version                  = "v1.25.0-eksbuild.1"
      service_account_role_arn = module.iam.ebs_csi_driver_role_arn
    } : null
  }
}

# Kubernetes provider configuration
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# AWS Load Balancer Controller (via Helm)
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.aws_load_balancer_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks,
    module.iam
  ]
}

# Cluster Autoscaler (via Helm)
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }

  depends_on = [
    module.eks,
    module.iam
  ]
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name              = var.project_name
  environment               = var.environment
  github_actions_role_arn   = module.iam.github_actions_role_arn
  eks_node_group_role_arn   = module.iam.node_group_role_arn
  common_tags               = local.common_tags
}

# ArgoCD Module
module "argocd" {
  count = var.enable_argocd ? 1 : 0
  source = "./modules/argocd"

  cluster_name                  = local.cluster_name
  environment                   = var.environment
  github_org                    = var.github_org
  github_repo                   = var.github_repo
  ecr_repository_url            = module.ecr.repository_url
  argocd_admin_password         = var.argocd_admin_password
  argocd_ecr_role_arn           = module.iam.argocd_ecr_role_arn
  enable_load_balancer          = var.argocd_enable_load_balancer
  enable_ingress                = var.argocd_enable_ingress
  argocd_domain                 = var.argocd_domain
  certificate_arn               = var.argocd_certificate_arn
  create_fenwave_application    = var.create_fenwave_application
  fenwave_namespace             = var.fenwave_namespace

  depends_on = [
    module.eks,
    module.iam,
    module.ecr
  ]
}