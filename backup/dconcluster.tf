#
# Resource Group
#
resource "azurerm_resource_group" "test" {
  name     = "testResourceGroup1"
  location = "West US"

  tags {
    environment = "Production"
  }
}

#
# Resource Group
#


