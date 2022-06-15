# Assign namespace for certmanager
resource "kubernetes_namespace" "certmanager" {
    depends_on = [
        azurerm_kubernetes_cluster.cluster
    ]
    metadata {
        name = "certmanager"
    }
}
# Use helm to deploy certmanager in cluster
resource "helm_release" "certmanager" {
    depends_on = [
        kubernetes_namespace.certmanager
    ]
    name = "certmanager"
    namespace = "certmanager"
    repository = "https://charts.jetstack.io"
    chart = "cert-manager"

    set {
        name  = "installCRDs"
        value = "true"
    }    
}

# Force Terraform to wait
resource "time_sleep" "wait_for_certmanager" {
    depends_on = [
        helm_release.certmanager
    ]
    create_duration = "10s"
}

