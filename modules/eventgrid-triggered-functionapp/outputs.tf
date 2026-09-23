output "function_app_url" {
  description = "Base URL of the Function App. Within Locally this is a *.furnace.locally address."
  value       = "https://${azurerm_linux_function_app.functionapp.default_hostname}"
}

output "received_url" {
  description = "The read-back endpoint. GET it to see every event the trigger has been handed; DELETE it to clear the list."
  value       = "https://${azurerm_linux_function_app.functionapp.default_hostname}/api/received"
}

output "function_app_name" {
  description = "The name of the deployed Function App."
  value       = azurerm_linux_function_app.functionapp.name
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.functionapp.name
}

output "system_topic_name" {
  description = "The subscription-scoped system topic raising resource-write events."
  value       = azurerm_eventgrid_system_topic.functionapp.name
}

output "postgres_server_name" {
  description = "The PostgreSQL flexible server the function writes events into."
  value       = azurerm_postgresql_flexible_server.functionapp.name
}

output "database_name" {
  description = "The database the function creates and owns for its events."
  value       = var.database_name
}
