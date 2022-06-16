# Assign namespace for certmanager
resource "kubernetes_namespace" "certmanager" {
    depends_on = [
        azurerm_kubernetes_cluster.cluster
    ]
    metadata {
        name = "certmanager"
    }
}

# Intiates Cloudflare secret for Kubernetes
resource "kubernetes_secret" "cloudflare_api_key_secret" {
    depends_on = [
        kubernetes_namespace.certmanager
    ]
    metadata {
        name = "cloudflare-api-key-secret"
        namespace = "certmanager"
    }

    data = {
        api-key = "${var.cloudflare_api_key}"
    }
    type = "Opaque"
}

# Assign deployments/cloudflare.yml file to a data value 
data "kubectl_path_documents" "cloudflare" {
    pattern = "./deployments/cloudflare.yml"
    vars = {
        cloudflare-email = "${var.cloudflare_email}"
        }
}

# Create a ClusterIssuer, pulls yaml information from deployments/cloudflare.yml
resource "kubectl_manifest" "cloudflare_prod" {
    for_each     = toset(data.kubectl_path_documents.cloudflare.documents)       
    yaml_body    = each.value
    
    depends_on = [time_sleep.wait_for_certmanager]
}

resource "cloudflare_record" "cluster" {
    zone_id = var.cloudflare_zonid
    name = var.cloudflare_domainname
    value =  azurerm_public_ip.cluster.ip_address
    type = "A"
    proxied = false

    depends_on = [azurerm_lb.traefik_lb]
}


# Force Terraform to wait
resource "time_sleep" "wait_for_clusterissuer" {
    depends_on = [
        kubectl_manifest.cloudflare_prod
    ]
    create_duration = "30s"
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
