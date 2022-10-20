locals {
  public_subnet_ids  = [for subnet in var.vpc.data.infrastructure.public_subnets : element(split("/", subnet["arn"]), 1)]
  private_subnet_ids = [for subnet in var.vpc.data.infrastructure.private_subnets : element(split("/", subnet["arn"]), 1)]
  subnet_ids         = concat(local.public_subnet_ids, local.private_subnet_ids)

  cluster_name = var.md_metadata.name_prefix
}

resource "aws_eks_cluster" "cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids = local.subnet_ids
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster-eks,
    aws_iam_role_policy_attachment.cluster-vpc,
  ]
}

resource "aws_eks_node_group" "node_group_x86" {
  node_group_name = "${local.cluster_name}-node_group_x86"
  cluster_name    = local.cluster_name
  ami_type        = "AL2_x86_64"
  version         = var.k8s_version
  subnet_ids      = local.private_subnet_ids
  node_role_arn   = aws_iam_role.node.arn
  instance_types  = ["t3.medium", "t3.large"]

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 1
  }

  lifecycle {
    create_before_destroy = true
    // desired_size issue: https://github.com/aws/containers-roadmap/issues/1637
    ignore_changes = [
      scaling_config.0.desired_size,
    ]
  }

  depends_on = [
    aws_eks_cluster.cluster
  ]
}

resource "aws_eks_node_group" "node_group_arm64" {
  node_group_name = "${local.cluster_name}-node_group_arm64"
  cluster_name    = local.cluster_name
  ami_type        = "AL2_ARM_64"
  version         = var.k8s_version
  subnet_ids      = local.private_subnet_ids
  node_role_arn   = aws_iam_role.node.arn
  instance_types  = ["t4g.medium", "t4g.large"]

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 1
  }

  lifecycle {
    create_before_destroy = true
    // desired_size issue: https://github.com/aws/containers-roadmap/issues/1637
    ignore_changes = [
      scaling_config.0.desired_size,
    ]
  }

  depends_on = [
    aws_eks_cluster.cluster
  ]
}
