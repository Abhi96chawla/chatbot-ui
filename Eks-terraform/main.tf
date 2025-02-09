# Define IAM policy for assuming the EKS role
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Create IAM role for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-cloud11"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

# Attach AmazonEKSClusterPolicy to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Get VPC data
data "aws_vpc" "default_vpc" {
  default = true
}

# Get public subnets for the cluster
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Create the EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.public_subnets.ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment
  ]
}

# IAM role for EC2 instances in the node group
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-cloud"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the node group role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_registry_readonly_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Create the EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = data.aws_subnets.public_subnets.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t2.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_attachment,
    aws_iam_role_policy_attachment.eks_cni_policy_attachment,
    aws_iam_role_policy_attachment.ecs_registry_readonly_attachment
  ]
}
