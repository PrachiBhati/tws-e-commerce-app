########################
# Security Group for Node Group SSH access
########################
resource "aws_security_group" "node_group_remote_access" {
  name   = "node-group-ssh-access"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow SSH (for Bastion access)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten in prod
  }

  egress {
    description = "Allow all outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-node-sg"
  }
}

########################
# IAM Role for EKS Access
########################
resource "aws_iam_role" "eks_access_role" {
  name = "eks-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::386636311568:root" # trust entire account
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Allow terraform user to assume this role
resource "aws_iam_policy" "allow_terraform_assume_role" {
  name        = "allow-terraform-assume-eks-access-role"
  description = "Allow terraform user to assume eks-access-role"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Resource = aws_iam_role.eks_access_role.arn
      }
    ]
  })
}

# Attach policy to terraform user
resource "aws_iam_user_policy_attachment" "terraform_user_assume" {
  user       = "eks-demo" # replace with your actual IAM user
  policy_arn = aws_iam_policy.allow_terraform_assume_role.arn
}

# Attach Admin to the Role
resource "aws_iam_role_policy_attachment" "eks_access_attach" {
  role       = aws_iam_role.eks_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

########################
# EKS Cluster
########################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = local.name
  cluster_version                 = "1.31"
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Access entries (RBAC via AWS Auth)
  access_entries = {
    example = {
      principal_arn = aws_iam_role.eks_access_role.arn

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Cluster addons
  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = { most_recent = true }
  }

  # Security group rules
  cluster_security_group_additional_rules = {
    access_for_bastion_jenkins_hosts = {
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all HTTPS traffic from jenkins and Bastion host"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      type        = "ingress"
    }
  }

  ########################
  # Node Group(s)
  ########################
  eks_managed_node_group_defaults = {
    instance_types = ["t3.micro"] # ✅ free-tier eligible
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    demo-ng = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.micro"] # ✅ avoid failure from before
      capacity_type  = "ON_DEMAND"

      disk_size                  = 20
      use_custom_launch_template = false

      remote_access = {
        ec2_ssh_key               = aws_key_pair.deployer.key_name
        source_security_group_ids = [aws_security_group.node_group_remote_access.id]
      }

      tags = {
        Name        = "demo-ng"
        Environment = "dev"
      }
    }
  }

  tags = merge(local.tags, { "created_by" = "eks-demo" })
}

########################
# List EKS Node Instances
########################
data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = module.eks.cluster_name
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.eks]
}