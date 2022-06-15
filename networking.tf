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

