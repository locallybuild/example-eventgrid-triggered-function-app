# ---------------------------------------------------------------------------
# Event Grid - a system topic scoped to the whole subscription, so the events
# are the ones Azure raises itself when resources are deployed. No topic to
# publish to by hand: the source is the subscription, and every resource write
# anywhere in it flows through here.
#
# topic_type Microsoft.Resources.Subscriptions is what makes it subscription-
# scoped, and such a topic must live in the "Global" location regardless of
# where its resources are.
# ---------------------------------------------------------------------------
data "azurerm_subscription" "current" {}

resource "azurerm_eventgrid_system_topic" "functionapp" {
  name                = "${var.prefix}-topic"
  resource_group_name = azurerm_resource_group.functionapp.name
  location            = "Global"
  source_resource_id  = data.azurerm_subscription.current.id
  topic_type          = "Microsoft.Resources.Subscriptions"
}

# ---------------------------------------------------------------------------
# The subscription that points the topic at the function.
#
# azure_function_endpoint is the thing to notice. Unlike a webhook
# subscription, the destination is an ARM resource id rather than a URL: Event
# Grid resolves the app itself, reads the system key the Functions host
# provisions for the Event Grid extension, and delivers to the app's extension
# webhook with that key. Nothing here holds a URL or a secret.
#
# included_event_types narrows the firehose to successful resource writes - a
# resource deployed or updated. Drop it to receive everything the subscription
# raises (deletes, failed writes, actions like listKeys), or add more types to
# the list. The whole set is Microsoft.Resources.ResourceWriteSuccess,
# ResourceWriteFailure, ResourceWriteCancel, and the Delete/Action variants.
#
# The subscription depends on the function app implicitly, through
# receiver_function_id - so the code is already deployed and the function
# already indexed by the time the subscription exists.
# ---------------------------------------------------------------------------
resource "azurerm_eventgrid_system_topic_event_subscription" "functionapp" {
  name                  = "${var.prefix}-to-function"
  system_topic          = azurerm_eventgrid_system_topic.functionapp.name
  resource_group_name   = azurerm_resource_group.functionapp.name
  event_delivery_schema = "EventGridSchema"

  included_event_types = ["Microsoft.Resources.ResourceWriteSuccess"]

  azure_function_endpoint {
    function_id = local.receiver_function_id
  }
}
