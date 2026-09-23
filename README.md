```
ooooo                                      oooo  oooo              
`888'                                      `888  `888              
 888          .ooooo.   .ooooo.   .oooo.    888   888  oooo    ooo 
 888         d88' `88b d88' `\"Y8 `P  )88b   888   888   `88.  .8'
 888         888   888 888        .oP\"888   888   888    `88..8'
 888       o 888   888 888   .o8 d8(  888   888   888     `888'
o888ooooood8 `Y8bod8P' `Y8bod8P' `Y888\"\"8o o888o o888o     .8'
                                                       .o..P'
                                                       `Y8P'
```

# Event Grid triggered Function App on Locally

This example shows how to deploy an Event Grid triggered Function App - which records every resource deployment in your subscription into PostgreSQL - to [Locally Build](https://locally.build).

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended).
* [Node.js](https://nodejs.org) 20+, to install the function's dependencies.
* The Locally Plugin for `Microsoft.DBforPostgreSQL` installed (`locally plugin install --name Microsoft.DBforPostgreSQL`).
* The Locally Plugin for `Microsoft.EventGrid` installed (`locally plugin install --name Microsoft.EventGrid`).
* The Locally Plugin for `Microsoft.Storage` installed (`locally plugin install --name Microsoft.Storage`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).

## Running the example

First up, we need to ensure Locally is running, which can be launched via:

```bash
locally build
```

The Function App is deployed from a zip that Terraform builds from `function/`, so we first install its dependencies:

```bash
cd function
npm install
cd ..
```

With Locally running, in another terminal we can initialise Terraform, which both downloads the providers we need and then configures the modules for use:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> It's possible to use OpenTofu here by substituting `terraform` for `tofu`.

With Terraform initialised, we can then provision the example by running:

```bash
locally run terraform apply
```

One apply creates the resource group, storage account, plan and Function App, pushes the code into the app, creates the subscription-scoped Event Grid system topic, and subscribes the function to it.

## Triggering the function

The system topic watches the whole subscription, so deploying any resource fires the function. Note that it's writes to *resources* that raise the event, not the resource group that contains them - so deploy a resource, for example a storage account:

```bash
locally run az group create -n trigger-rg -l berlin
locally run az storage account create -n triggersa$RANDOM -g trigger-rg -l berlin --sku Standard_LRS
```

Delivery is picked up on a poll, so give it a few seconds, then read back everything the function has been handed from the `received_url` output:

```bash
curl "$(locally run terraform output -raw received_url)"
```

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```

The `trigger-rg` resource group you created above to fire an event isn't part of this configuration, so remove it separately:

```bash
locally run az group delete -n trigger-rg --yes
```
