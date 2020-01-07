resource "random_id" "server" {
    keepers = {
        ami_id = 1
    }

    byte_length = 8
}

#
# Create random password for BIG-IP
#
resource "random_password" "password" {
    length           = 16
    special          = true
    override_special = "_%@"
}

resource "azurerm_key_vault" "bigip-vault" {
    name                = format("kv%s", random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    tenant_id           = data.azurerm_client_config.current.tenant_id

    sku_name = "premium"

    access_policy {
        tenant_id = data.azurerm_client_config.current.tenant_id
        object_id = data.azurerm_client_config.current.object_id

        key_permissions = [
        "create",
        "get",
        ]

        secret_permissions = [
        "set",
        "get",
        "delete",
        "list",
        ]
    }

    tags = {
        environment = var.environment
    }
}
resource "azurerm_key_vault_secret" "bigip-password" {
    name         = format("bigip-password-%s",random_id.randomId.hex)
    value        = random_password.password.result
    key_vault_id = azurerm_key_vault.bigip-vault.id

    tags = {
        environment = var.environment
    }
}

data "azurerm_client_config" "current" {}
