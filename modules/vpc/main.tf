terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  # Private subnets reach the internet through NAT; a single NAT keeps costs low.
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # Required for EKS + AWS Load Balancer Controller subnet auto-discovery.
  public_subnet_tags = merge(
    { "kubernetes.io/role/elb" = "1" },
    var.public_subnet_tags,
  )
  private_subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = "1" },
    var.private_subnet_tags,
  )

  tags = var.tags
}
