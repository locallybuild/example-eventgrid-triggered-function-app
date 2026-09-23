variable "prefix" {
  description = "Name prefix for all resources. On Azure, make it globally unique - storage account and Function App names are global there, where within Locally they only have to be unique in your instance."
  type        = string
  default     = "locally-demo"
}

variable "location" {
  description = "Region name (e.g. berlin within Locally, or uksouth on Azure). Confirm the ones your instance has with `locally regions list`."
  type        = string
  default     = "berlin"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources in this example."
  type        = map(string)
  default     = {}
}

variable "service_plan_sku" {
  description = "App Service plan SKU (Linux)."
  type        = string
  default     = "B1"
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "database_name" {
  description = "Name of the database the function creates (and owns) for its events."
  type        = string
  default     = "events"
}

variable "receiver_function_name" {
  description = "Name of the Event Grid triggered function the subscription delivers to. Case-sensitive, and must match the name the code registers in function/src/functions/eventgrid.js."
  type        = string
  default     = "EventGridReceiver"
}
