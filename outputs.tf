output "url_where_application_is_available_on" {
  value = "https://${azurerm_linux_function_app.this.default_hostname}"
}
