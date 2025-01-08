locals {
  package_url = "${azurerm_storage_blob.this.url}${data.azurerm_storage_account_sas.this.sas}"
}
