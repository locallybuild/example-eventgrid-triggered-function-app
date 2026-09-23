# ---------------------------------------------------------------------------
# PostgreSQL - where the function stores the events it receives.
#
# The app never uses a password: it logs in with its managed identity's Entra
# token (see function/src/db.js). Locally, like Azure, still requires an
# administrator_login on the server, so one is set with a generated password that
# nothing in the app ever reads - Entra auth is the only path the function takes.
#
# active_directory_auth_enabled is what turns on the token path;
# password_auth_enabled stays on only because the server demands an admin login.
# ---------------------------------------------------------------------------
locals {
  # Postgres flexible server names are 3-63 lowercase alphanumerics/hyphens.
  postgres_server_name = "${var.prefix}-pg"
}

data "azurerm_client_config" "current" {}

resource "random_password" "postgres_admin" {
  length      = 24
  special     = true
  min_special = 2
}

resource "azurerm_postgresql_flexible_server" "functionapp" {
  name                = local.postgres_server_name
  resource_group_name = azurerm_resource_group.functionapp.name
  location            = azurerm_resource_group.functionapp.location

  version    = "16"
  sku_name   = var.postgres_sku_name
  storage_mb = 32768

  administrator_login    = "pgadmin"
  administrator_password = random_password.postgres_admin.result

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }
}

# Register the Function App's managed identity as the server's Entra administrator.
# principal_name becomes the Postgres login role the token maps to, so it must
# match PGUSER (the function app's name) exactly. As an Entra admin the identity
# may CREATE DATABASE, which is how the app owns and provisions its own database.
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "functionapp" {
  server_name         = azurerm_postgresql_flexible_server.functionapp.name
  resource_group_name = azurerm_resource_group.functionapp.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_linux_function_app.functionapp.identity[0].principal_id
  principal_name      = local.function_app_name
  principal_type      = "ServicePrincipal"
}
