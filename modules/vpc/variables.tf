variable "name" {
  description = "Name to be used on all VPC resources as identifier"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across. EKS requires the control plane to span at least 2 AZs, so provide at least 2 even for a single-zone workload."
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks (for load balancers and NAT gateway)"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks (for the EKS control plane ENIs and application worker nodes)"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Provision NAT Gateway(s) so private subnets get outbound internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway (cost optimized) instead of one per AZ"
  type        = bool
  default     = true
}

variable "public_subnet_names" {
  description = "Explicit Name tags for public subnets (one per AZ). When empty, names are auto-generated from the VPC name."
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  description = "Explicit Name tags for private subnets (one per AZ). When empty, names are auto-generated from the VPC name."
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "EKS cluster name used for kubernetes.io/cluster subnet discovery tags"
  type        = string
  default     = null
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets (Kubernetes ELB discovery tags are merged in by the module)"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets (Kubernetes internal-ELB discovery tags are merged in by the module)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
