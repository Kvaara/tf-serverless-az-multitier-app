resource "random_string" "this" {
  length  = 24
  special = false
  upper   = false
}

// Resource groups are logical compartments/containers for resources in Azure
// Every resource in Azure has to belong to a Resource Group.
// Resource Groups are the 3rd highest-level resources with close to no dependencies.
// 2nd rank goes to Subscriptions (which contain multiple resource groups) 
// 1st rank goes to Management Groups, which organize Subscriptions.
// Resource Groups' location DOES NOT force you to create all the resources under it into the same location.
resource "azurerm_resource_group" "this" {
  name     = "${var.namespace}-rg"
  location = var.location
}

// An Azure Storage Account is required because Azure Function Apps store runtime metadata, such as
// function triggers and logs. They also store files and deployment artifacts there.
// Without an Azure Storage Account functions would be functionless.
resource "azurerm_storage_account" "this" {
  name                     = random_string.this.result
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "this" {
  name                  = "${var.namespace}-sc"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

module "ballroom" {
  source = "terraform-in-action/ballroom/azure"
}

resource "azurerm_storage_blob" "this" {
  name                   = "server.zip"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this.name
  type                   = "Block"
  source                 = module.ballroom.output_path
}

// SAS is an acronym meaning Shared Access Signature
// We can generate SAS' using this data source to distribute read-only access to blobs.
data "azurerm_storage_account_sas" "this" {
  connection_string = azurerm_storage_account.this.primary_connection_string

  resource_types {
    object    = true
    service   = false
    container = false
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = "2025-01-01T00:00:00Z"
  expiry = "2048-06-19T00:00:00Z"

  permissions {
    read    = true
    filter  = false
    tag     = false
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
  }
}

// An App Service always runs in a service plan.
// Azure Functions can also run in a service plan.
// An App Service plan defines a set of compute resources your app runs on.
// Compute resources run in the same location where you've created the Service Plan.
resource "azurerm_service_plan" "this" {
  name                = "${var.namespace}-sp"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  // Consumption plans are referred as dynamic or `Y1`
  // See: https://learn.microsoft.com/en-us/azure/azure-functions/consumption-plan#create-a-consumption-plan-function-app
  sku_name = "Y1"
}

resource "azurerm_application_insights" "this" {
  name                = "${var.namespace}-appin"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
}


resource "azurerm_linux_function_app" "this" {
  name                = "${var.namespace}-fn"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  https_only = true

  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  service_plan_id            = azurerm_service_plan.this.id

  site_config {
    // When this is set, Terraform automatically creates the `APPINSIGHTS_INSTRUMENTATIONKEY` environment variable with the below value in the app_settings block.
    application_insights_key = azurerm_application_insights.this.instrumentation_key
    application_stack {
      // When this is set, Terraform automatically creates the `FUNCTIONS_WORKER_RUNTIME` variable with the value `node` and the `WEBSITE_NODE_DEFAULT_VERSION` variable with the below value in the app_settings block.
      node_version = "20"
    }
    // `WEBSITES_MAX_DYNAMIC_APPLICATION_SCALE_OUT`
    app_scale_limit = 1
  }
  functions_extension_version = "~4"
  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = local.package_url
    // The below is available only on Windows Function apps: https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_node_default_version
    # WEBSITE_NODE_DEFAULT_VERSION = "10.14.1"
    TABLES_CONNECTION_STRING    = data.azurerm_storage_account_sas.this.connection_string
    AzureWebJobsDisableHomepage = true
  }
}
