# Create virtual network
resource "azurerm_virtual_network" "main" {
    name                = format("%s-vnet-%s",var.prefix,random_id.randomId.hex)
    address_space       = [var.cidr]
    location            = var.region
    resource_group_name = azurerm_resource_group.main.name

    tags = {
        environment = var.environment
    }
}

# Create subnet
resource "azurerm_subnet" "management" {
    count                = length(var.azs)
    name                 = format("%s-managementsubnet-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefix       = cidrsubnet(var.cidr, 8, 10 + count.index)
}
# Create subnet
resource "azurerm_subnet" "public" {
    count                = length(var.azs)
    name                 = format("%s-publicsubnet-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefix       = cidrsubnet(var.cidr, 8, 20 + count.index)
}
# Create subnet
resource "azurerm_subnet" "private" {
    count                = length(var.azs)
    name                 = format("%s-privatesubnet-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefix       = cidrsubnet(var.cidr, 8, 30 + count.index)
}