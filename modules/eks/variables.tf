variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. 1.33) for the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "ID of the VPC in which the cluster is created"
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs for the EKS control plane ENIs. Must span at least 2 AZs (AWS requirement)."
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs where the managed worker nodes are placed. Pass a single private subnet to keep the workload in one zone."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable the public Kubernetes API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable the private Kubernetes API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint. Restrict this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the identity running Terraform/OpenTofu cluster admin via an access entry"
  type        = bool
  default     = true
}

variable "node_group_key" {
  description = "Map key for the managed node group inside the EKS module"
  type        = string
  default     = "app"
}

variable "node_group_name" {
  description = "AWS name for the managed node group (visible in the EKS console and EC2 tags)"
  type        = string
}

variable "node_iam_role_name" {
  description = "Fixed IAM role name for the node group (avoids AWS 38-char name_prefix limit)"
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group: ON_DEMAND or SPOT"
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

variable "node_disk_size" {
  description = "EBS root volume size (GiB) for each worker node"
  type        = number
  default     = 50
}

variable "addons" {
  description = "Map of EKS cluster addons to enable"
  type        = any
  default = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }
}

variable "tags" {
  description = "Tags applied to all EKS resources"
  type        = map(string)
  default     = {}
}
