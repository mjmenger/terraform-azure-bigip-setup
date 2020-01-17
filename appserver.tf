# Create virtual machine
resource "azurerm_virtual_machine" "appserver" {
    count                 = length(var.azs)
    name                  = format("%s-appserver-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.app_nic[count.index].id]
    vm_size               = "Standard_DS1_v2"
    zones                 = [element(var.azs,count.index)]

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true


    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = format("%s-appserver-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = format("%s-appserver-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = var.publickeyfile
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "app_nic" {
    count                     = length(var.azs)
    name                      = format("%s-app-nic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.app_sg.id

    ip_configuration {
        name                          = format("%s-app-nic-%s",var.prefix,random_id.randomId.hex)
        subnet_id                     = azurerm_subnet.private[count.index].id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = var.environment
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "app_sg" {
    name                = format("%s-app_sg-%s",var.prefix,random_id.randomId.hex)
    location            = var.region
    resource_group_name = azurerm_resource_group.main.name
    
    # extend the set of security rules to address the needs of
    # the applications deployed on the application server
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = var.cidr # only allow traffic from within the virtual network
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.environment
    }
}