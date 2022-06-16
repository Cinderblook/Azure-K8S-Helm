# Overview

 Deplying helm charts in Kubernetes within Azure using the AKS service.

 Check out this on my site: [Cinderblook.com](https://www.cinderblook.com/blog/terraform-azure-k8s-helm/)

- Build a cluster that is running a few services 
- Have cluster automatically scale with load
- Have Kubeconfig file available so it can be managed, changed, altered, destroyed, etc.
- Ensure Kubeconfig file is secure, and is being encrypted with traffic involved in this
- Create a NGINX certificate service utilizing Cloudflare's DNS
- Use Traefik as a loadbalancer, and utilize ingresses for reachable internal services

### Prerequisites
1. Have an Azure account
    - *[if you are a student, sign up for a student account and get some free credits along side it.](https://azure.microsoft.com/en-us/free/students/)*
2. Have a Cloudflare Account & a Domain 


## Outlined in this post

1. [Create a public and private key](#creating-the-public--private-keys)
2. [Setup Cloudflare](#setting-up-cloudflare) 
    - Obtain a public domain
    - Generate a Token for DNS Read and write access
3. [Setup Terraform files for the deployment](#terraform-process)
    - [Providers](#setting-up-providers-azurerm-kubernetes-helm)
    - [Infrastructure](#setting-up-infrastructure)
    - [Kubernetes, Kubectl, & Helm](#setting-up-the-kubernetes--helm-attributes)
    - [Assigning Variables](#assigning-variable-to-variablestfvars)
    - [Creating Output](#creating-output-to-be-sent-back-after-terraform-finishes-running)
4. [Run it](#run-it)
5. [Terraform State and Kubeconfig file](#gain-access-to-kubectl)
6. [Now What?](#now-what)
7. [Useful Resources](#useful-resources)

## Creating the Public & Private keys

First step we'll tackle is the creation of your public and private keys. 

I find the easiest way to do this, is to open up a terminal (Powershell and/or pretty much any linux terminal) and type in a quick few commands. To keep it short and sweet, we will just use `ssh-keygen`

Ensure you save this to a locaiton you will remember, it'll be important not to loose either key. This'll allow you SSH access into your Kubernetes cluster.

Copy your public key you genereated into the same folder as your .tf files will be located.

## Setting up Cloudflare

Second step on our list, is to setup Cloudflare.

Cloudflare is important here, since it will be handing out certificates to services running within the Kubernetes cluster. Luckily, [signing up for Cloudflare is free](https://dash.cloudflare.com/login), and I'll go over how to obtain a Token for API access.

Once you have created your account, and have obtained a public domain, you should see a page similar to the following; 

Scroll down on the overview tab, and on the right hand side, there should be a 'Get your API token' link. On the following page, click 'Create token'

Scroll down to the bottom, and select 'Create Custom Token`. On the following page, ensure you give your token a memorable name, assign it permissions to read and edit DNS zone settings, and limit it to your respective Zone resources (Domain). Set the TTL to the duration of your project.

Continue to summary, and collect the API token key, store it discretely. This Token will be used in Terraform, within the .tfvars file later for authentication with the Cloudflare API.

## Terraform Process

I prefer to seperate my Terraform files for readability, feel free to see all the code at a glance on the [Github Repo](https://github.com/Cinderblook/Azure-K8S-Helm). I'll do a breakdown here in this section.

### Setting up Providers; Azurerm, Kubernetes, Helm, Kubectl

In this situation, I am authenticating to Azure using their AzureCLI. Refer to [Microsoft's official documentation for Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) setup. Kubernetes, Kubectl, and Helm don't require and specific authentication. The API Token generated earlier to authenticate with Cloudflare. This'll be defined in the .tfvars file.

Take the following code, and put it into a file called providers.tf

```tf
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
```

### Setting up infrastructure

I sepereated the 'structure' into a few seperate files. One for networking aspects in Azure; `networking.tf`. Another for the k8s cluster itself (AKS); `cluster.tf`.

Within the networking file, it will setup firewall rules for the virtual private network, create the network itself, and create a load balancer.

```tf
# Resource Group for Terraform deployment
resource "azurerm_resource_group" "cluster" {
  name     = "${var.prefix}-cluster"
  location = var.region
}

# Networking Setup for Cluster
resource "azurerm_virtual_network" "cluster" {
  name                = "${var.prefix}-network"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  address_space       = ["10.1.0.0/16"]
}

# Assign subnet for Cluster
resource "azurerm_subnet" "cluster" {
  name                 = "${var.prefix}-subnet"
  virtual_network_name = azurerm_virtual_network.cluster.name
  resource_group_name  = azurerm_resource_group.cluster.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Firewall settings for cluster
resource "azurerm_network_security_group" "cluster" {
  name                = "Allow-RDP-SSH-KCTL"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTPS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "443"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
   security_rule {
    name                       = "k8s-api"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "6443"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Force Terraform to wait
resource "time_sleep" "wait_for_kubernetes" {
    depends_on = [azurerm_kubernetes_cluster.cluster]
    create_duration = "20s"
}

# Create public IP for load balancer
resource "azurerm_public_ip" "cluster" {
  name                = "K8S-PublicIPAddress"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  allocation_method   = "Static"
}

# Assign loadbalancer to a Data variable, for user later
resource "azurerm_lb" "traefik_lb" {
    depends_on = [helm_release.traefik]
    name = "k8s-traefik-lb"
    resource_group_name = azurerm_resource_group.cluster.name
    location            = azurerm_resource_group.cluster.location
    frontend_ip_configuration {
      name                 = azurerm_public_ip.cluster.name
      public_ip_address_id = azurerm_public_ip.cluster.id
    }
}


```

Within the cluster file, we'll define the virtual machine AKS structure being created. 
```tf
# Create Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix          = "${var.prefix}-aks"

    linux_profile {
        admin_username = var.linux_user

        ssh_key {
            key_data = file(var.ssh_public_key)
        }
    }

  default_node_pool {
    name                = "agentpool"
    node_count          = var.cluster_nodes_count
    vm_size             = "Standard_B2s"
    type                = "VirtualMachineScaleSets"
    #availability_zones  = ["1", "2"]
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3

    # Required for advanced networking
    vnet_subnet_id = azurerm_subnet.cluster.id
  }
    ### Uncomment this and add id/secret for management 
    #service_principal {
    #    client_id     = var.aks_service_principal_app_id
    #    client_secret = var.aks_service_principal_client_secret
    #}

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
  #addon_profile {
  #    oms_agent {
  #    enabled                    = true
  #    log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
  #    }
  #}
  tags = {
    Environment = "Development"
  }
}

# Assign credentials to data, used for helm, kubernetes, and kubectl providers.
data "azurerm_kubernetes_cluster" "credneitals" {
  name                = azurerm_kubernetes_cluster.cluster.name
  resource_group_name = azurerm_resource_group.cluster.name
  depends_on          = [azurerm_kubernetes_cluster.cluster]
}

# Pull kubeconfig to your local machine
resource "local_file" "kubeconfig" {
  depends_on   = [azurerm_kubernetes_cluster.cluster]
  filename     = "./kubeconfig"
  content      = azurerm_kubernetes_cluster.cluster.kube_config_raw
}
```

### Setting up the Kubernetes & Helm attributes

First file we'll make is a `nginx.tf` file. Within it we will define the manifest attributes of the deployment, and setup an ingress for accessing the service

```tf
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
```

The second step setup, is to define `cloudflare.tf` file for setting up Cloudflare and the certmanager aspect. This will be done by using Kubectl manifest, namespace creation, and a Helm chart deployment.

```tf
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

```

### Assigning variable to variables.tfvars

First create and define variables within a `variables.tf` file.

```tf
variable "cluster_name" {
  default = "terraformclust"
}

variable "cluster_nodes_count" {
  default = "2"
}

variable "region" {
  default = "East US 2"
}

variable "prefix" {
  default = "test"
}

variable "ssh_public_key"{
  default = "./id_rsa.pub"
}

variable "cloudflare_api_key" {}
variable "cloudflare_email" {}
variable "cloudflare_api_key_secret" {}
variable "cloudflare_prod_account_key" {}
variable "cloudflare_zonid" {}
variable "cloudflare_domainname" {}
variable "cloudflare_token" {}

variable "linux_user" {}

```

Assign correct Cloudflare information into the `tfvariables.auto.tfvars` file. Follow along with the `tfvariables.auto.tfvars.example` file.

```tf
cloudflare_api_key = "api key here"                                 # This should have DNS read/write permissions in Cloudflare 
cloudflare_email   = "email associated to account"                  # Used to login with
cloudflare_api_key_secret = "Cloudflare key secret"                 # Used for cloudflare.yml file
cloudflare_prod_account_key = "Cloudflare production account key"   # Used for cloudflare.yml file
cloudflare_zonid = "Zone ID for cloudflare account"                 # Used for Cloudflare resource
cloudflare_domainname = "domain name"                               # Used for Cloudflare resource
cloudflare_token = "cloudflare token"

linux_user = "username"                                             #Admin access to cluster master(s)
```

 As for the SSH key, ensure you have a .pub file that you are pulling data from, or directly put SSH key into into variable file.

## Creating output to be sent back after Terraform finishes running

An important step, is creating necessary output data to result from running the terraform apply. In this scenario, it is critical to have data from the cluster such as certificate information, the kubeconfig, and cluster credentials. Luckily, since these are obviously sensitive data, we can force a `sensitive = true` attribute to them, and just have the State file hold onto that information. This'll allow us to pull the Kube config to control the K8S cluster to our machine.

```tf
# It is necessary to identify these variables for usage later when updating the state file or using kubectl commands
output "client_key" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.client_key
  sensitive = true
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate
  sensitive = true
}

output "cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "cluster_username" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.username
  sensitive = true
}

output "cluster_password" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.password
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.cluster.kube_config_raw
  sensitive = true
}

output "host" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.host
  sensitive = true
}

# Critical to get kubectl file connected out to Azure for local environment
output "cluster_name" {
  value = azurerm_kubernetes_cluster.cluster.name
}

output "resource_group_name" {
  value = azurerm_resource_group.cluster.name
}

#Public IP of Cluster
output "cluster_public_ip" {
  value = azurerm_public_ip.cluster.ip_address
}


```

## Run it

Once everything is setup and ready to roll, navigate into the directory containing all terraform files. 

1. Run a `terraform init`
2. Then `terraform validate` 
3. If everything checks out, run `terraform apply`, and in roughly 5 minutes you should have a running AKS cluster in Azure!

## Gain access to Kubectl

In order to gain access from your local machine, we will use the azure CLI. If you followed the tutorial, you'll already be logged in, `az login`. Use the following command to set your environment varialbe for kubectl to control kubernetes cluster in Azure.
`az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw cluster_name)`

Once ran, you can verify it is connected and working with `kubectl get nodes` , `kubectl get namespace`

## Now what?

Congragulations! The hard part of getting started, is now over. You now have a ready to spin up AKS cluster in Azure prebuilt with a loadbalancer and certificate automation. From here, the possibilites are limitless. 

## Useful Resources

* [Kubernetes Overview](https://learnk8s.io/terraform-aks)
* [Terraform Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)
* [Terraform Azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
* [Terraform Helm](https://registry.terraform.io/providers/hashicorp/helm/2.5.0)

https://github.com/xcad2k/boilerplates/tree/main/terraform/templates/kubernetes-automation-example
https://www.youtube.com/watch?v=kFt0OGd_LhI&t=870s