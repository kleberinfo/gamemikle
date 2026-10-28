data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_static_web_app" "game" {
  name                = "${var.project_name}-${var.environment}-${random_id.suffix.hex}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = var.location

  sku_tier = var.sku_tier
  sku_size = var.sku_tier == "Free" ? "Free" : "Standard"

  preview_environments_enabled = true
  tags = {
    application = "GameMiKle"
    environment = var.environment
    managed_by  = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}
