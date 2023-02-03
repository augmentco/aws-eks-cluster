locals {
  cacert_base64   = data.aws_eks_cluster.cluster.certificate_authority[0].data
  oidc_issuer_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  data_authentication = {
    cluster = {
      server                     = data.aws_eks_cluster.cluster.endpoint
      certificate-authority-data = local.cacert_base64
    }
    // We need to set the "user" here, but the token won't be generated til the next step
    user = {
      token = lookup(kubernetes_secret_v1.massdriver-cloud-provisioner_token.data, "token")
    }
  }
  data_infrastructure = {
    arn             = data.aws_eks_cluster.cluster.arn
    oidc_issuer_url = local.oidc_issuer_url
  }
  specs_kubernetes = {
    cloud            = "aws"
    distribution     = "eks"
    version          = data.aws_eks_cluster.cluster.version
    platform_version = data.aws_eks_cluster.cluster.platform_version
  }
  specs_aws = {
    region = var.vpc.specs.aws.region
  }

  kubernetes_cluster_artifact = {
    data = {
      infrastructure = local.data_infrastructure
      authentication = local.data_authentication
    }
    specs = {
      kubernetes = local.specs_kubernetes
      aws        = local.specs_aws
    }
  }
}

resource "massdriver_artifact" "kubernetes_cluster" {
  field                = "kubernetes_cluster"
  provider_resource_id = data.aws_eks_cluster.cluster.arn
  name                 = "EKS Cluster Credentials ${data.aws_eks_cluster.cluster.name} [${var.vpc.specs.aws.region}]"
  artifact             = jsonencode(local.kubernetes_cluster_artifact)
}
