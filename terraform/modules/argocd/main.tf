# Namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      name = var.argocd_namespace
    }
  }
}

# ArgoCD Helm Chart
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_version

  values = [
    templatefile("${path.module}/configs/argocd-values.yaml", {
      domain                = var.argocd_domain
      cluster_name          = var.cluster_name
      environment           = var.environment
      github_org            = var.github_org
      github_repo           = var.github_repo
      ecr_repository_url    = var.ecr_repository_url
      load_balancer_enabled = var.enable_load_balancer
      argocd_ecr_role_arn   = var.argocd_ecr_role_arn  

    })
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

# ArgoCD CLI Secret
resource "kubernetes_secret" "argocd_cli" {
  metadata {
    name      = "argocd-cli-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    admin-password = var.argocd_admin_password
  }

  type = "Opaque"
}

# Service Account for ArgoCD with ECR access
resource "kubernetes_service_account" "argocd_ecr" {
  metadata {
    name      = "argocd-ecr-sa"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.argocd_ecr_role_arn
    }
  }
}

# ArgoCD Application for Fenwave IDP
resource "kubectl_manifest" "fenwave_app" {
  count = var.create_fenwave_application ? 1 : 0

  yaml_body = templatefile("${path.module}/configs/fenwave-application.yaml", {
    namespace          = kubernetes_namespace.argocd.metadata[0].name
    github_repo        = var.github_repo
    github_org         = var.github_org
    target_namespace   = var.fenwave_namespace
    image_repository   = var.ecr_repository_url
    environment        = var.environment
  })

  depends_on = [
    helm_release.argocd
  ]
}

# Ingress for ArgoCD (optional)
resource "kubernetes_ingress_v1" "argocd" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "argocd-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/backend-protocol"     = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn"      = var.certificate_arn
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
    }
  }

  spec {
    rule {
      host = var.argocd_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}