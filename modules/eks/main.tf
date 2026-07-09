terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.52"
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Networking: control plane ENIs span all provided (>= 2 AZ) subnets,
  # while worker nodes are pinned to node_subnet_ids (a single private subnet).
  vpc_id                   = var.vpc_id
  control_plane_subnet_ids = var.control_plane_subnet_ids
  subnet_ids               = var.node_subnet_ids

  # API server endpoint access.
  endpoint_private_access      = var.endpoint_private_access
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # IRSA (OIDC provider) for workload IAM roles.
  enable_irsa = true

  # Let the caller manage the cluster via EKS access entries.
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  addons = var.addons

  eks_managed_node_groups = {
    (var.node_group_key) = {
      name = var.node_group_name

      # Nodes stay in a single private ("app") subnet -> single zone.
      subnet_ids = var.node_subnet_ids

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = var.node_disk_size

      labels = {
        role      = "app"
        capacity  = lower(var.node_capacity_type)
        nodegroup = var.node_group_name
      }

      tags = {
        Name      = var.node_group_name
        Component = "nodegroup"
        Capacity  = var.node_capacity_type
      }
    }
  }

  tags = var.tags
}
