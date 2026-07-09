terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.52"
    }
  }

  backend "local" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "OpenTofu"
      Project     = var.project_name
      Stack       = var.name_prefix
    }
  }
}

locals {
  # Single naming pattern for every resource: eks-sdtest-{resource}
  #   eks-sdtest-vpc
  #   eks-sdtest-eks
  #   eks-sdtest-public-us-east-1a
  #   eks-sdtest-private-app-us-east-1a
  #   eks-sdtest-ondemand-ng  |  eks-sdtest-spot-ng

  vpc_name     = "${var.name_prefix}-vpc"
  cluster_name = "${var.name_prefix}-eks"

  node_group_key     = lower(var.node_capacity_type) == "spot" ? "spot" : "ondemand"
  node_group_name    = "${var.name_prefix}-${local.node_group_key}-ng"
  node_iam_role_name = "${var.name_prefix}-${local.node_group_key}-ng-role"

  public_subnet_names = [
    for az in var.availability_zones : "${var.name_prefix}-public-${az}"
  ]

  private_subnet_names = [
    for az in var.availability_zones : "${var.name_prefix}-private-app-${az}"
  ]

  # Single-zone workload: worker nodes are placed in exactly one private subnet.
  # The EKS control plane still needs subnets in >= 2 AZs (AWS hard requirement).
  node_subnet_ids = [element(module.vpc.private_subnets, var.node_az_index)]

  common_tags = merge(var.common_tags, {
    Stack = var.name_prefix
  })
}

# =============================================================================
# VPC - public + private subnets across the configured AZs, single NAT gateway
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  name = local.vpc_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  public_subnet_names  = local.public_subnet_names
  private_subnet_names = local.private_subnet_names
  cluster_name         = local.cluster_name

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  public_subnet_tags = {
    Component = "network"
    Tier      = "public"
  }

  private_subnet_tags = {
    Component = "network"
    Tier      = "private"
  }

  tags = merge(local.common_tags, {
    Component = "vpc"
  })
}

# =============================================================================
# EKS - control plane spans the private subnets, app node group is single-zone
# =============================================================================
module "eks" {
  source = "./modules/eks"

  aws_region         = var.aws_region
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_subnets
  node_subnet_ids          = local.node_subnet_ids

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_group_key      = local.node_group_key
  node_group_name     = local.node_group_name
  node_iam_role_name  = local.node_iam_role_name
  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = merge(local.common_tags, {
    Component = "eks"
  })

  # Explicit ordering: finish VPC networking before creating the cluster.
  depends_on = [
    module.vpc,
  ]
}
