terraform {
  required_version = ">= 0.14.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    helm = {
        source = "hashicorp/helm"
        version = "~>2.5.1"
    }
    kubernetes = {
        source = "hashicorp/kubernetes"
        version = "~> 2.8.0"     
    }
    kubectl = {
        source = "gavinbunney/kubectl"
        version = "~> 1.14.0"
    }
    cloudflare = {
        source = "cloudflare/cloudflare"
        version = "~> 3.16.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host        = data.azurerm_kubernetes_cluster.credneitals.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.cluster_ca_certificate)

}

provider "helm" {
  kubernetes {
    host        = data.azurerm_kubernetes_cluster.credneitals.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.cluster_ca_certificate)    
  }
}

provider "kubectl" {
    host        = data.azurerm_kubernetes_cluster.credneitals.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credneitals.kube_config.0.cluster_ca_certificate)  
    load_config_file = false
}

provider "cloudflare" {
  # Comment out key & email if using token
    #email = var.cloudflare_email
    #api_key = var.cloudflare_api_key
    api_token = var.cloudflare_token
}