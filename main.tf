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
    }
  }
}

locals {
  name = "${var.project_name}-${var.environment}"

  # Single-zone workload: worker nodes are placed in exactly one private subnet.
  # The EKS control plane still needs subnets in >= 2 AZs (AWS hard requirement),
  # which is why the VPC is built across var.availability_zones.
  node_subnet_ids = [element(module.vpc.private_subnets, var.node_az_index)]
}

# =============================================================================
# VPC - public + private subnets across the configured AZs, single NAT gateway
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = var.common_tags
}

# =============================================================================
# EKS - control plane spans the private subnets, app node group is single-zone
# =============================================================================
module "eks" {
  source = "./modules/eks"

  cluster_name       = "${local.name}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_subnets
  node_subnet_ids          = local.node_subnet_ids

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = var.common_tags
}
