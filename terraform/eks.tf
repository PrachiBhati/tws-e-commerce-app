####################
# eks.tf (minimal)
####################

# Security Group for Node Group SSH access
resource "aws_security_group" "node_group_remote_access" {
  name   = "node-group-ssh-access"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow SSH (for Bastion access)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-node-sg"
  }
}

# Reuse keypair (make sure this exists in another file, e.g. ec2.tf)
# resource "aws_key_pair" "deployer" { ... }  <-- keep this only once in your configs

# Minimal EKS module config
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = "1.31"

  # If you want to access API publicly for testing, set public true; else keep private
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # VPC & subnets (expects module.vpc to exist)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Minimal addons
  cluster_addons = {
    coredns   = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni   = { most_recent = true }
  }

  # Managed node group(s) - cost-minimised config
  eks_managed_node_groups = {
    small-ng = {
      desired_size = 1
      min_size     = 1
      max_size     = 1

      # Use a micro instance to try to stay inside EC2 free-tier (if eligible)
      instance_types = ["t3.micro"]
      capacity_type  = "SPOT"   # use "SPOT" only if you are OK with interruptions

      use_custom_launch_template = false

      disk_size = 20

      # remote access via the keypair and SG you already created elsewhere
      remote_access = {
        ec2_ssh_key               = aws_key_pair.deployer.key_name
        source_security_group_ids = [aws_security_group.node_group_remote_access.id]
      }

      tags = {
        Name        = "${local.name}-ng"
        Environment = "dev"
      }

      # ensure the keypair & SG exist before nodegroup creation
      depends_on = [
        aws_key_pair.deployer,
        aws_security_group.node_group_remote_access
      ]
    }
  }

  tags = merge(local.tags, { "created_by" = "terraform" })
}

# Optional: small data source to list running node instances (will populate when nodes up)
data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = module.eks.cluster_id
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.eks]
}
