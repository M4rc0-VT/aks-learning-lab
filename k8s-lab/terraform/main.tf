# 1. We tell Terraform which providers we need
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # This grabs the latest stable version of the Azure plugin
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# 2. We configure the Azure Provider
provider "azurerm" {
  features {} # This empty block is required by the plugin to work
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

# 3. Our First Resource: A Resource Group
resource "azurerm_resource_group" "aks_rg" {
  name     = "rg-terraform-lab"
  location = "North Central US" # Matches your manual region
}

# 4. The AKS Cluster Resource
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-terraform-lab"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "aks-lab"

  # The "Cost Conscious" Node Pool
  default_node_pool {
    name       = "default"
    node_count = 1                     # Manual Scale (1 Node)
    vm_size    = "Standard_D2as_v5"    # The economical choice we found
  }

  # Identity: We let Azure manage the credentials (no passwords needed)
  identity {
    type = "SystemAssigned"
  }

  # The "Expert" Network Profile
  network_profile {
    network_plugin      = "azure"      # Use Azure CNI
    network_plugin_mode = "overlay"    # The "Overlay" mode (Saves IPs!)
    network_policy      = "calico"     # Security Policy engine
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }
}

# 5. The Container Registry (Private Vault)
resource "azurerm_container_registry" "acr" {
  name                = "acrlearninglab${random_string.suffix.result}" # Must be globally unique!
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = "Basic"           # Cheapest option for learning
  admin_enabled       = true              # Allows simple username/password login for now
}

# 6. Random String for Unique Names
# (Azure requires globally unique names for ACR, so we generate a random suffix)
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# 7. Grant AKS permission to Pull from ACR
resource "azurerm_role_assignment" "aks_to_acr" {
  # The "Who": The Kubelet (the agent on the node that actually pulls images)
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  # The "What": The "AcrPull" role (Read-only access)
  role_definition_name = "AcrPull"

  # The "Where": Your specific registry
  scope = azurerm_container_registry.acr.id

  # Skip checks to make it faster for labs
  skip_service_principal_aad_check = true
}

# 8. Install the Ingress Controller (The Doorbell) automatically
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-basic"
  create_namespace = true

  # Start it only AFTER the cluster is ready
  depends_on = [azurerm_role_assignment.aks_to_acr]

  # Set the specific health probe value we learned about manually
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
}

# 9. Create a namespace for monitoring tools
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# 10. Install the Prometheus & Grafana Stack using Helm
resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  # Expert Tip: This stack is HUGE. We increase the timeout so Terraform doesn't panic.
  timeout    = 600
  
  # We set "atomic" to true so if it fails, it cleans up after itself.
  atomic     = true 
}

