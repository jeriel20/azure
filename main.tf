# Configure the Azure provider
provider "azurerm" {
    version = "=2.0"
    features {}
}

# Create a new resource group
resource "azurerm_resource_group" "devops1" {
    name     = "myDevopsGroup"
    location = "eastus"
    tags = {
      Environment = "Terraform TSI-DEV"
      Team = "DevOps"
  }
}
