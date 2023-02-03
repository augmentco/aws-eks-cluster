locals {
  enable_ebs_csi = true
}

module "ebs_csi" {
  source = "github.com/massdriver-cloud/terraform-modules//k8s/aws-ebs-csi-driver?ref=ffad03a"
  // Using a count here in case we ever want to back this out to a conditional
  count               = local.enable_ebs_csi ? 1 : 0
  kubernetes_version  = var.k8s_version
  eks_cluster_arn     = data.aws_eks_cluster.cluster.arn
  eks_oidc_issuer_url = local.oidc_issuer_url
}
