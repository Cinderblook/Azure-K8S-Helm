# nginx deployment
resource "kubernetes_namespace" "nginx" {
    depends_on = [
        azurerm_kubernetes_cluster.cluster
    ]
    metadata {
        name = "nginx"
    }
}
# Create the YAML configuration for nginx within the kubernetes provider
resource "kubernetes_deployment" "nginx" {
    depends_on = [
        kubernetes_namespace.nginx
    ]
    metadata {
        name = "nginx"
        namespace = "nginx"
        labels = {
            app = "nginx"
        }
    }
    spec {
        replicas = 1
        selector {
            match_labels = {
                app = "nginx"
            }
        }
        template {
            metadata {
                labels = {
                    app = "nginx"
                }
            }
            spec {
                container {
                    image = "nginx:latest"
                    name  = "nginx"

                    port {
                        container_port = 80
                    }
                }
            }
        }
    }
}

# Set namespace and port assignments for nginx access
resource "kubernetes_service" "nginx" {
    depends_on = [kubernetes_namespace.nginx]
    metadata {
        name = "nginx"
        namespace = "nginx"
    }
    spec {
        selector = {
            app = "nginx"
        }
        port {
            port = 80
        }
        type = "ClusterIP"
    }
}

# Create ingress for NGINX - Allow outside communication to it 
resource "kubernetes_ingress_v1" "nginx" {

    depends_on = [kubernetes_namespace.nginx]

    metadata {
        name = "nginx"
        namespace = "nginx"
    }

    spec {
        rule {

            host = "${var.cloudflare_domainname}"

            http {

                path {
                    path = "/"

                    backend {
                        service {
                            name = "nginx"
                            port {
                                number = 80
                            }
                        }
                    }

                }
            }
        }

        tls {
          secret_name = "nginx"
          hosts = ["${var.cloudflare_domainname}"]
        }
    }
}

# Assign deployments/nginx-cert.yml file to a data value 
data "kubectl_path_documents" "nginx" {
    pattern = "./deployments/nginx-cert.yml"
    vars = {
        cloudflare-domainname = "${var.cloudflare_domainname}"
    }
}
# Set nginx config, pulls yaml information from deployments/nginx-cert.yml 
resource "kubectl_manifest" "nginx-certificate" {
    for_each     = toset(data.kubectl_path_documents.nginx.documents)
    yaml_body    = each.value

    depends_on = [kubernetes_namespace.nginx, time_sleep.wait_for_clusterissuer]
}

resource "cloudflare_record" "cluster" {
    zone_id = var.cloudflare_zonid
    name = var.cloudflare_domainname
    value =  azurerm_public_ip.cluster.ip_address
    type = "A"
    proxied = false

    depends_on = [azurerm_lb.traefik_lb]
}
