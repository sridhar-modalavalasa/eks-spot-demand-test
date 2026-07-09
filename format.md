# Complete Terraform EKS with Private Subnets Setup

Here's the complete code for your structure:

## 📁 modules/vpc/variables.tf

```hcl
variable "name" {
  description = "Name of the VPC"
  type        = string
  default     = "eks-vpc"
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT gateway"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for VPC"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
```

## 📁 modules/vpc/main.tf

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      "Name"                                      = var.name
      "kubernetes.io/cluster/${var.name}"         = "shared"
      "Tier"                                      = "Network"
    },
    var.tags
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = "${var.name}-igw" },
    var.tags
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      "Name"                                      = "${var.name}-public-${var.azs[count.index]}"
      "Tier"                                      = "Public"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.name}"         = "shared"
    },
    var.tags
  )
}

# Private Subnets (for EKS Cluster and Nodes)
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(
    {
      "Name"                                      = "${var.name}-private-${var.azs[count.index]}"
      "Tier"                                      = "Private"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.name}"         = "shared"
    },
    var.tags
  )
}

# Elastic IPs for NAT Gateway
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"

  tags = merge(
    { "Name" = "${var.name}-nat-eip-${count.index + 1}" },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways in Public Subnets
resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    { "Name" = "${var.name}-nat-${count.index + 1}" },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    { "Name" = "${var.name}-public-rt" },
    var.tags
  )
}

# Private Route Table(s)
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    { "Name" = "${var.name}-private-rt-${count.index + 1}" },
    var.tags
  )
}

# Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations - Private
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
```

## 📁 modules/vpc/output.tf

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = aws_subnet.public[*].arn
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = aws_subnet.private[*].arn
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "azs" {
  description = "List of Availability Zones used"
  value       = var.azs
}
```

---

## 📁 modules/eks/variables.tf

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster and nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for load balancers"
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_irsa" {
  description = "Determines whether to create an OpenID Connect Provider for EKS to enable IRSA"
  type        = bool
  default     = true
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default     = {}
}

variable "cluster_addons" {
  description = "Map of cluster add-ons to create"
  type        = any
  default     = {}
}

variable "tags" {
  description = "Additional tags for EKS resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
```

## 📁 modules/eks/main.tf

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # VPC Configuration - CLUSTER in PRIVATE subnets only
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Cluster Endpoint Access Configuration
  cluster_endpoint_private_access       = var.cluster_endpoint_private_access
  cluster_endpoint_public_access        = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs  = var.cluster_endpoint_public_access_cidrs

  # Enable IRSA
  enable_irsa = var.enable_irsa

  # Cluster encryption configuration
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Cluster Add-ons
  cluster_addons = var.cluster_addons

  # EKS Managed Node Groups - Nodes in PRIVATE subnets
  eks_managed_node_groups = var.eks_managed_node_groups

  # Access Entries
  enable_cluster_creator_admin_permissions = true

  # Tags
  tags = merge(
    {
      "Environment" = var.environment
      "Project"     = var.cluster_name
    },
    var.tags
  )
}

# KMS Key for cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Cluster Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    { "Name" = "${var.cluster_name}-encryption-key" },
    var.tags
  )
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks-key"
  target_key_id = aws_kms_key.eks.key_id
}
```

## 📁 modules/eks/output.tf

```hcl
output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_identity_providers" {
  description = "Map of attribute maps for all identity providers"
  value       = module.eks.cluster_identity_providers
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS managed node groups"
  value       = module.eks.node_security_group_id
}

output "eks_managed_node_groups" {
  description = "Map of EKS managed node groups and their attributes"
  value       = module.eks.eks_managed_node_groups
}

output "configure_kubectl_script" {
  description = "Script to configure kubectl with cluster credentials"
  value       = "aws eks update-kubeconfig --region ap-south-1 --name ${module.eks.cluster_name}"
}
```

---

## 📁 main.tf (Root)

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# =============================================================================
# VPC Module - Creates VPC with Public and Private Subnets
# NAT Gateway in Public Subnets for Private Subnet internet access
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  name                = "${var.project_name}-vpc"
  cidr                = var.vpc_cidr
  azs                 = var.availability_zones
  public_subnets      = var.public_subnet_cidrs
  private_subnets     = var.private_subnet_cidrs
  single_nat_gateway  = var.single_nat_gateway
  enable_nat_gateway  = var.enable_nat_gateway
  environment         = var.environment
  tags                = var.common_tags
}

# =============================================================================
# EKS Module - Cluster and Nodes in PRIVATE Subnets
# Uses NAT Gateway for outbound internet access
# =============================================================================
module "eks" {
  source = "./modules/eks"

  cluster_name    = "${var.project_name}-eks-cluster"
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id

  # Private subnets for EKS cluster endpoints and worker nodes
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Public subnets for Load Balancers (ALB/NLB)
  public_subnet_ids = module.vpc.public_subnet_ids

  # Cluster endpoint access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs

  # Enable IRSA for service accounts
  enable_irsa = true

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent    = true
      before_compute = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.eks.ebs_csi_driver_iam_role_arn
    }
  }

  # EKS Managed Node Groups - All in PRIVATE subnets
  eks_managed_node_groups = {
    # Main worker node group
    worker-nodes = {
      instance_types = var.worker_instance_types
      min_size       = var.worker_min_size
      max_size       = var.worker_max_size
      desired_size   = var.worker_desired_size

      # Nodes will be placed in private subnets (inherited from module subnet_ids)
      capacity_type = "ON_DEMAND"

      labels = {
        Role        = "worker"
        Environment = var.environment
      }

      taints = []

      tags = {
        Name = "${var.project_name}-worker-nodes"
      }

      # Additional security group rules
      create_security_group = true

      # Node group update config
      update_config = {
        max_unavailable_percentage = 33
      }
    }

    # Spot instance node group for cost optimization
    spot-nodes = {
      instance_types = var.spot_instance_types
      min_size       = var.spot_min_size
      max_size       = var.spot_max_size
      desired_size   = var.spot_desired_size

      capacity_type = "SPOT"

      labels = {
        Role        = "spot-worker"
        Environment = var.environment
        Lifecycle   = "spot"
      }

      taints = [{
        key    = "spot-instance"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      tags = {
        Name = "${var.project_name}-spot-nodes"
      }

      update_config = {
        max_unavailable_percentage = 50
      }
    }
  }

  environment = var.environment
  tags        = var.common_tags
}
```

## 📁 variables.tf (Root)

```hcl
# =============================================================================
# AWS Configuration
# =============================================================================
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

# =============================================================================
# Project Configuration
# =============================================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "myproject"
}

variable "environment" {
  description = "Environment (dev/staging/production)"
  type        = string
  default     = "production"
}

# =============================================================================
# VPC Configuration
# =============================================================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (NAT Gateway + Load Balancers)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (EKS Cluster + Worker Nodes)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for cost optimization"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateways for private subnet internet access"
  type        = bool
  default     = true
}

# =============================================================================
# EKS Cluster Configuration
# =============================================================================
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS cluster API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

# =============================================================================
# Worker Node Group Configuration (ON_DEMAND)
# =============================================================================
variable "worker_instance_types" {
  description = "Instance types for worker nodes"
  type        = list(string)
  default     = ["t3.large"]
}

variable "worker_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "worker_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "worker_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

# =============================================================================
# Spot Node Group Configuration
# =============================================================================
variable "spot_instance_types" {
  description = "Instance types for spot nodes"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "t2.medium", "t2.large"]
}

variable "spot_min_size" {
  description = "Minimum number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum number of spot nodes"
  type        = number
  default     = 3
}

variable "spot_desired_size" {
  description = "Desired number of spot nodes"
  type        = number
  default     = 1
}

# =============================================================================
# Common Tags
# =============================================================================
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

## 📁 output.tf (Root)

```hcl
# =============================================================================
# VPC Outputs
# =============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT Gateway + Load Balancers)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS Cluster + Nodes)"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_public_ips
}

# =============================================================================
# EKS Cluster Outputs
# =============================================================================
output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS Cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "EKS Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS Node security group ID"
  value       = module.eks.node_security_group_id
}

# =============================================================================
# Node Group Outputs
# =============================================================================
output "worker_node_group" {
  description = "Worker node group details"
  value       = module.eks.eks_managed_node_groups["worker-nodes"]
}

output "spot_node_group" {
  description = "Spot node group details"
  value       = module.eks.eks_managed_node_groups["spot-nodes"]
}

# =============================================================================
# Useful Commands
# =============================================================================
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = module.eks.configure_kubectl_script
}

output "get_nodes_command" {
  description = "Command to get cluster nodes"
  value       = "kubectl get nodes -o wide"
}
```

## 📁 terraform.tfvars

```hcl
# =============================================================================
# Region Configuration
# =============================================================================
aws_region = "ap-south-1"

# =============================================================================
# Project Configuration
# =============================================================================
project_name = "myproject"
environment  = "production"

# =============================================================================
# VPC Configuration
# =============================================================================
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b",
  "ap-south-1c"
]

# Public Subnets - NAT Gateway & Load Balancers
public_subnet_cidrs = [
  "10.0.1.0/24",   # ap-south-1a
  "10.0.2.0/24",   # ap-south-1b
  "10.0.3.0/24"    # ap-south-1c
]

# Private Subnets - EKS Cluster & Worker Nodes
private_subnet_cidrs = [
  "10.0.101.0/24", # ap-south-1a
  "10.0.102.0/24", # ap-south-1b
  "10.0.103.0/24"  # ap-south-1c
]

# NAT Gateway Configuration
single_nat_gateway  = true   # Set to false for HA (one NAT per AZ)
enable_nat_gateway  = true

# =============================================================================
# EKS Cluster Configuration
# =============================================================================
cluster_version = "1.29"

# Restrict public access to your IP or VPN CIDR in production
cluster_public_access_cidrs = [
  "0.0.0.0/0"  # WARNING: Restrict this in production!
]

# =============================================================================
# ON_DEMAND Worker Node Group
# =============================================================================
worker_instance_types = ["t3.large"]
worker_min_size       = 1
worker_max_size       = 5
worker_desired_size   = 2

# =============================================================================
# SPOT Node Group (Cost Optimization)
# =============================================================================
spot_instance_types = ["t3.medium", "t3.large", "t2.medium"]
spot_min_size       = 0
spot_max_size       = 3
spot_desired_size   = 1

# =============================================================================
# Common Tags
# =============================================================================
common_tags = {
  Owner       = "devops-team"
  CostCenter  = "engineering"
  Project     = "myproject"
  Environment = "production"
}
```

---

## 📁 Final Folder Structure

```
.
├── modules/
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       └── output.tf
│
├── main.tf
├── variables.tf
├── output.tf
└── terraform.tfvars
```

---

## 🚀 Deployment Commands

```bash
# 1. Initialize Terraform
terraform init

# 2. Plan the changes
terraform plan -out=eks.tfplan

# 3. Apply the changes
terraform apply eks.tfplan

# 4. After successful deployment, configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name myproject-eks-cluster

# 5. Verify the cluster
kubectl get nodes
kubectl get pods -A
```

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        ap-south-1 (Mumbai)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      VPC (10.0.0.0/16)                    │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │              Internet Gateway (IGW)                  │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  │                          │                                │   │
│  │  ┌─────────────┬─────────┴─────────┬─────────────┐       │   │
│  │  │  PUBLIC     │  PUBLIC           │  PUBLIC     │       │   │
│  │  │  SUBNET     │  SUBNET           │  SUBNET     │       │   │
│  │  │  10.0.1.0/24│  10.0.2.0/24     │  10.0.3.0/24│       │   │
│  │  │  (1a)       │  (1b)             │  (1c)       │       │   │
│  │  │  ┌───────┐  │                   │             │       │   │
│  │  │  │ NAT   │  │                   │             │       │   │
│  │  │  │ GW    │  │                   │             │       │   │
│  │  │  └───┬───┘  │                   │             │       │   │
│  │  └──────┼──────┴───────────────────┴─────────────┘       │   │
│  │         │                                                  │   │
│  │  ┌──────┴──────────┬──────────────────┬──────────────┐    │   │
│  │  │  PRIVATE        │  PRIVATE         │  PRIVATE     │    │   │
│  │  │  SUBNET         │  SUBNET          │  SUBNET     │    │   │
│  │  │  10.0.101.0/24  │  10.0.102.0/24   │  10.0.103.0/24│   │
│  │  │  (1a)           │  (1b)            │  (1c)       │    │   │
│  │  │  ┌───────────┐  │  ┌───────────┐   │  ┌───────────┐│   │
│  │  │  │EKS Cluster│  │  │  Worker   │   │  │  Worker   ││   │
│  │  │  │ Endpoint  │  │  │  Nodes    │   │  │  Nodes    ││   │
│  │  │  │ (Private) │  │  │ (Private) │   │  │ (Private) ││   │
│  │  │  └───────────┘  │  └───────────┘   │  └───────────┘│   │
│  │  └─────────────────┴──────────────────┴──────────────┘    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│              ┌─────────────────────────────┐                    │
│              │  Load Balancers (Public)    │                    │
│              │  ALB/NLB in Public Subnets  │                    │
│              └─────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Important Notes

1. **Private Cluster**: The EKS cluster API endpoint runs in private subnets. Public access is enabled but can be restricted via `cluster_public_access_cidrs`.

2. **NAT Gateway**: Single NAT gateway is used for cost optimization. Set `single_nat_gateway = false` for high availability (one NAT per AZ).

3. **Security**: In production, restrict `cluster_public_access_cidrs` to your office IP or VPN CIDR.

4. **Spot Instances**: Spot nodes have taints to prevent critical workloads from scheduling on them.