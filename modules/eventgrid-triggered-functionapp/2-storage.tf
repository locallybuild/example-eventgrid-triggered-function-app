# ---------------------------------------------------------------------------
# Storage - the Functions host's own bookkeeping account. Every Function App
# needs one; this app's code never touches it.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "functionapp" {
  name                     = substr("${replace(var.prefix, "-", "")}sa", 0, 24)
  resource_group_name      = azurerm_resource_group.functionapp.name
  location                 = azurerm_resource_group.functionapp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
