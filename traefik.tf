# Traefik Deployment
resource "kubernetes_namespace" "traefik" {
    metadata {
      name = "traefik"
    }
}

resource "helm_release" "traefik" {
  
  depends_on = [
    kubernetes_namespace.traefik
  ]

  name = "traefik"
  namespace = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"

  set {
    name  = "ingressClass.enabled"
    value = "true"
  }

  set {
    name  = "ingressClass.isDefaultClass"
    value = "true"
  }

  set {
      name = "ports.web.redirectTo"
      value = "websecure"
  }

  set {
      name = "ports.websecure.tls.enabled"
      value = "true"
  }
}

data "kubernetes_service" "traefik" {
 metadata {
   name = helm_release.traefik.name
   namespace = helm_release.traefik.namespace
 }
}
