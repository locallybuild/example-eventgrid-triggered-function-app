output "function_app_url" {
  description = "Base URL of the Function App. Within Locally this is a *.furnace.locally address."
  value       = module.eventgrid-triggered-functionapp.function_app_url
}

output "received_url" {
  description = "The read-back endpoint. GET it to see every event the trigger has been handed; DELETE it to clear the list."
  value       = module.eventgrid-triggered-functionapp.received_url
}

output "function_app_name" {
  description = "The name of the deployed Function App."
  value       = module.eventgrid-triggered-functionapp.function_app_name
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = module.eventgrid-triggered-functionapp.resource_group
}

output "system_topic_name" {
  description = "The subscription-scoped system topic raising resource-write events."
  value       = module.eventgrid-triggered-functionapp.system_topic_name
}
