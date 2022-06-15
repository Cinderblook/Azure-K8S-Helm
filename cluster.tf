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