# =============================================================================
# Region / Project
# =============================================================================
aws_region   = "us-east-1"
project_name = "eks-spot-demand"
environment  = "test"

# =============================================================================
# VPC
# =============================================================================
vpc_cidr = "10.0.0.0/16"

# AZs must belong to aws_region above.
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

# Worker nodes run only in the first private subnet -> single zone (us-east-1a).
node_az_index = 0

# Single shared NAT gateway for cost optimization.
enable_nat_gateway = true
single_nat_gateway = true

# =============================================================================
# EKS
# =============================================================================
kubernetes_version = "1.33"

# WARNING: open to the world for practice. Restrict to your IP/VPN CIDR in prod.
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

# =============================================================================
# Node group
# =============================================================================
node_instance_types = ["t3.large"]
node_capacity_type  = "ON_DEMAND" # use SPOT to get eks-spot-demand-test-spot-ng
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2

# =============================================================================
# Tags
# =============================================================================
common_tags = {
  Owner = "devops"
}
