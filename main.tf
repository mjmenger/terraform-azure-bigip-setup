# Configure the Microsoft Azure Provider
provider "azurerm" {

}

terraform {
    backend "azurerm" {
    }
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "main" {
    name     = format("%s-resourcegroup-%s",var.prefix,random_id.randomId.hex)
    location = var.region

    tags = {
        environment = var.environment
    }
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = format("%sdiagstorage%s",var.prefix,random_id.randomId.hex)
    resource_group_name         = azurerm_resource_group.main.name
    location                    = azurerm_resource_group.main.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = var.environment
    }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "securitygroup" {
    name                = format("%s-securitygroup-%s",var.prefix,random_id.randomId.hex)
    location            = var.region
    resource_group_name = azurerm_resource_group.main.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.environment
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    # keepers = {
    #     # Generate a new ID only when a new resource group is defined
    #     resource_group = azurerm_resource_group.resourcegroup.name
    # }
    
    byte_length = 2
}



