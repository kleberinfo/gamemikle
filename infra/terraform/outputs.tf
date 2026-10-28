output "static_web_app_url" {
  description = "Public HTTPS URL for the GameMiKle website."
  value       = "https://${azurerm_static_web_app.game.default_host_name}"
}

output "static_web_app_name" {
  description = "Azure Static Web App resource name."
  value       = azurerm_static_web_app.game.name
}

output "deployment_token" {
  description = "Token used by the official Azure Static Web Apps GitHub Action. Store it only as a GitHub Actions secret."
  value       = azurerm_static_web_app.game.api_key
  sensitive   = true
}
