# ---------------------------------------------------------------------------
# App Service Plan - hosts the Function App
# ---------------------------------------------------------------------------
locals {
  function_app_name = "${var.prefix}-func"

  # The Event Grid subscription addresses ONE function inside the app, by
  # resource id. Terraform has no handle on a function that arrives in a zip,
  # so the id is composed from the app's id and the function's name.
  #
  # The name is case-sensitive: it travels to the Functions host as the
  # functionName the delivery is addressed to, and is matched exactly. It must
  # be the name the code registers - app.eventGrid("EventGridReceiver", …) in
  # function/src/functions/eventgrid.js.
  receiver_function_id = "${azurerm_linux_function_app.functionapp.id}/functions/${var.receiver_function_name}"
}

resource "azurerm_service_plan" "functionapp" {
  name                = "${var.prefix}-plan"
  resource_group_name = azurerm_resource_group.functionapp.name
  location            = azurerm_resource_group.functionapp.location
  os_type             = "Linux"
  sku_name            = var.service_plan_sku
}

# ---------------------------------------------------------------------------
# Function App package - zips function/ from the inside, so host.json lands at
# the root of the archive (a zip containing a function/ directory deploys an
# app with no functions in it). Run `npm install` in function/ first so its
# node_modules are included in the archive.
# ---------------------------------------------------------------------------
data "archive_file" "functionapp" {
  type        = "zip"
  source_dir  = "${path.module}/../../function"
  output_path = "${path.module}/../../function.zip"
}

# ---------------------------------------------------------------------------
# The Function App, with its code.
#
# zip_deploy_file pushes the package over the site's SCM plane during apply,
# so a single `terraform apply` leaves a running app rather than an empty one.
# WEBSITE_RUN_FROM_PACKAGE = "1" is what the provider requires alongside it,
# and it means "run the package that was pushed" rather than fetching one from
# a URL.
#
# The push authenticates with the site's publishing credentials over HTTP
# Basic, which is allowed on a newly created site. If you have turned it off
# (basicPublishingCredentialsPolicies/scm), the push is refused and the error
# says so.
# ---------------------------------------------------------------------------
resource "azurerm_linux_function_app" "functionapp" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.functionapp.name
  location            = azurerm_resource_group.functionapp.location
  service_plan_id     = azurerm_service_plan.functionapp.id

  storage_account_name       = azurerm_storage_account.functionapp.name
  storage_account_access_key = azurerm_storage_account.functionapp.primary_access_key

  zip_deploy_file = data.archive_file.functionapp.output_path

  # A system-assigned managed identity is what the app authenticates to Postgres
  # with - no database password is ever configured. The identity is registered as
  # the server's Entra administrator in 3-database.tf.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node"

    # Required by the provider whenever zip_deploy_file is set.
    WEBSITE_RUN_FROM_PACKAGE = "1"

    # Passwordless Postgres. The fqdn embeds the port ("host:port"); the code
    # splits it. PGUSER is the Entra principal name the server maps to a login
    # role - it must equal the administrator's principal_name in 3-database.tf.
    PGHOST     = azurerm_postgresql_flexible_server.functionapp.fqdn
    PGDATABASE = var.database_name
    PGUSER     = local.function_app_name
  }

  tags = var.tags
}
