provider "azurerm" {
  features {}
}

module "eventgrid-triggered-functionapp" {
  source = "../../modules/eventgrid-triggered-functionapp"

  prefix   = "locally-demo"
  location = "berlin"
  tags = {
    ProvisionedBy = "Terraform"
  }

  providers = {
    azurerm = azurerm
  }
}
