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

resource "aws_eks_node_group" "node_group" {
  for_each        = { for ng in var.node_groups : ng.name_suffix => ng }
  node_group_name = "${local.cluster_name}-${each.value.name_suffix}"
  cluster_name    = local.cluster_name
  version         = var.k8s_version
  subnet_ids      = local.private_subnet_ids
  node_role_arn   = aws_iam_role.node.arn
  instance_types  = [each.value.instance_type]

  scaling_config {
    desired_size = each.value.min_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  dynamic "taint" {
    for_each = each.value.advanced_configuration_enabled ? [each.value.advanced_configuration.taint] : []
    content {
      key    = taint.value.taint_key
      value  = taint.value.taint_value
      effect = taint.value.effect
    }
  }

  lifecycle {
    create_before_destroy = true
    // desired_size issue: https://github.com/aws/containers-roadmap/issues/1637
    ignore_changes = [
      scaling_config.0.desired_size,
    ]
  }

  # adding tags will cause a provisioning error!
  # don't add tags here
  # tags = var.md_metadata.default_tags

  depends_on = [
    aws_eks_cluster.cluster
  ]
}
