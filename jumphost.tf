# Create virtual machine
resource "azurerm_virtual_machine" "jumphost" {
    count                 = length(var.azs)
    name                  = format("%s-jumphost-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.jh_nic[count.index].id]
    vm_size               = "Standard_DS1_v2"
    zones                 = [element(var.azs,count.index)]

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true 

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = format("%s-jumphost-%s-%s",var.prefix,count.index,random_id.randomId.hex)
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
        computer_name  = format("%s-jumphost-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = file(var.publickeyfile)
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.environment
    }
}

# Create network interface
resource "azurerm_network_interface" "jh_nic" {
    count                     = length(var.azs)
    name                      = format("%s-jh-nic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.jh_sg.id

    ip_configuration {
        name                          = format("%s-jh-nic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        subnet_id                     = azurerm_subnet.public[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.jh_public_ip[count.index].id
    }

    tags = {
        environment = var.environment
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "jh_sg" {
    name                = format("%s-jh_sg-%s",var.prefix,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
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




# Create public IPs
resource "azurerm_public_ip" "jh_public_ip" {
    count               = length(var.azs)
    name                = format("%s-jh-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static" # Static is required due to the use of the Standard sku
    sku                 = "Standard" # the Standard sku is required due to the use of availability zones
    zones               = [element(var.azs,count.index)]

    tags = {
        environment = var.environment
    }
}

#
# Create and place the inventory.yml file for the ansible demo
#
resource "null_resource" "transfer" {
    count = length(var.azs)
    provisioner "file" {
        content     = templatefile(
            "${path.module}/hostvars_template.yml",
                {
                    bigip_host_ip          = azurerm_network_interface.mgmt-nic[count.index].private_ip_address#bigip_host_ip = module.bigip.mgmt_public_ips[count.index]  the ip address that the bigip has on the management subnet
                    bigip_host_dns         = azurerm_network_interface.ext-nic[count.index].private_ip_address # the DNS name of the bigip on the public subnet
                    bigip_domain           = "${var.region}.compute.internal"
                    bigip_username         = "admin"
                    bigip_password         = random_password.password.result
                    ec2_key_name           = basename(var.privatekeyfile) 
                    ec2_username           = "azureuser"
                    log_pool               = cidrhost(cidrsubnet(var.cidr,8,count.index + 30),250)
                    bigip_external_self_ip = azurerm_network_interface.ext-nic[count.index].private_ip_address # the ip address that the bigip has on the public subnet
                    bigip_internal_self_ip = azurerm_network_interface.int-nic[count.index].private_ip_address # the ip address that the bigip has on the private subnet
                    juiceshop_virtual_ip   = azurerm_network_interface.ext-nic[count.index].private_ip_addresses[1]
                    grafana_virtual_ip     = azurerm_network_interface.ext-nic[count.index].private_ip_addresses[2]
                    appserver_gateway_ip   = cidrhost(cidrsubnet(var.cidr,8,count.index + 30),1)
                    appserver_guest_ip     = azurerm_network_interface.app_nic[count.index].private_ip_address
                    appserver_host_ip      = azurerm_network_interface.jh_nic[count.index].private_ip_address   # the ip address that the jumphost has on the public subnet
                    bigip_dns_server       = "8.8.8.8"
                }
        )

        destination = "~/inventory.yml"

        connection {
            type        = "ssh"
            user        = "azureuser"
            private_key = file(var.privatekeyfile)
            host        = azurerm_public_ip.jh_public_ip[count.index].ip_address
        }
    }
}