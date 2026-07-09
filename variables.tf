# =============================================================================
# AWS / Project
# =============================================================================
variable "aws_region" {
  description = "AWS region for all resources (single region)"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project identifier used to name resources"
  type        = string
  default     = "eks-practice"
}

variable "environment" {
  description = "Environment name (dev/staging/production)"
  type        = string
  default     = "dev"
}

# =============================================================================
# VPC
# =============================================================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs the VPC subnets are spread across. Keep at least 2 because the EKS control plane requires subnets in 2 AZs, even though the app nodes run in a single zone."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (NAT gateway + load balancers), one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private (app) subnets (EKS control plane + worker nodes), one per AZ"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "node_az_index" {
  description = "Index into the private subnet list that determines the single zone the worker nodes run in"
  type        = number
  default     = 0
}

variable "enable_nat_gateway" {
  description = "Provision NAT gateway(s) for private subnet outbound internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cost optimized)"
  type        = bool
  default     = true
}

# =============================================================================
# EKS
# =============================================================================
variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access" {
  description = "Enable the public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public API endpoint. Restrict this in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# Managed node group (single-zone app workers)
# =============================================================================
variable "node_instance_types" {
  description = "Instance types for the worker nodes"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for the worker nodes: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

# =============================================================================
# Tags
# =============================================================================
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
