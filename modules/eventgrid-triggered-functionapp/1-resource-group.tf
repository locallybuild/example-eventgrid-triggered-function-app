# ---------------------------------------------------------------------------
# Resource Group - which contains the deployed resources
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "functionapp" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}
