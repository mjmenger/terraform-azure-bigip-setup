# Create F5 BIGIP VMs 
resource "azurerm_virtual_machine" "f5bigip" {
    count                        = length(var.azs)
    name                         = format("%s-bigip-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                     = azurerm_resource_group.main.location
    resource_group_name          = azurerm_resource_group.main.name
    primary_network_interface_id = azurerm_network_interface.mgmt-nic[count.index].id
    network_interface_ids        = [azurerm_network_interface.mgmt-nic[count.index].id, azurerm_network_interface.ext-nic[count.index].id,azurerm_network_interface.int-nic[count.index].id]
    vm_size                      = var.instance_type
    zones                        = [element(var.azs,count.index)]

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    delete_os_disk_on_termination = true


    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "f5-networks"
        offer     = var.product
        sku       = var.image_name
        version   = var.bigip_version
    }

    storage_os_disk {
        name              = format("%s-bigip-osdisk-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "80"
    }

    os_profile {
        computer_name  = format("%s-bigip-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        admin_username = "azureuser"
        admin_password = random_password.password.result
        custom_data    = data.template_file.vm_onboard.rendered
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    plan {
        name          = var.image_name
        publisher     = "f5-networks"
        product       = var.product
    }

    tags = {
        Name           = format("%s-bigip-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment    = "${var.environment}"
    }
}

# Run Startup Script
resource "azurerm_virtual_machine_extension" "run_startup_cmd" {
    count                = length(var.azs)
    name                 = format("%s-bigip-startup-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location             = azurerm_resource_group.main.location
    resource_group_name  = azurerm_resource_group.main.name
    virtual_machine_name = azurerm_virtual_machine.f5bigip[count.index].name
    publisher            = "Microsoft.OSTCExtensions"
    type                 = "CustomScriptForLinux"
    type_handler_version = "1.2"

    settings = <<SETTINGS
        {
            "commandToExecute": "bash /var/lib/waagent/CustomData"
        }
    SETTINGS

    tags = {
        Name           = format("%s-bigip-startup-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment    = var.environment
    }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "management_sg" {
    name                = format("%s-mgmt_sg-%s",var.prefix,random_id.randomId.hex)
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

    security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }


    tags = {
        environment = var.environment
    }
}

# Create interfaces for the BIGIPs 
resource "azurerm_network_interface" "mgmt-nic" {
    count                     = length(var.azs)
    name                      = format("%s-mgmtnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.management_sg.id

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.management[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.management_public_ip[count.index].id
    }

    tags = {
        Name        = format("%s-mgmtnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment = var.environment
    }
}

# Create Application Traffic Network Security Group and rule
resource "azurerm_network_security_group" "application_sg" {
    name                = format("%s-app_sg-%s",var.prefix,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.environment
    }
}

resource "azurerm_network_interface" "ext-nic" {
    count                     = length(var.azs)
    name                      = format("%s-extnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.application_sg.id
    enable_ip_forwarding      = true

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.public[count.index].id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }

    ip_configuration {
        name                          = "juiceshop"
        subnet_id                     = azurerm_subnet.public[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.juiceshop_public_ip[count.index].id
}

    ip_configuration {
        name                          = "grafana"
        subnet_id                     = azurerm_subnet.public[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.grafana_public_ip[count.index].id
    }

    tags = {
        Name           = format("%s-extnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment    = var.environment

    }
}

resource "azurerm_network_interface" "int-nic" {
    count                     = length(var.azs)
    name                      = format("%s-intnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.management_sg.id
    enable_ip_forwarding      = true

    ip_configuration {
        name                          = "primary"
        subnet_id                     = azurerm_subnet.private[count.index].id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }

    tags = {
        Name           = format("%s-intnic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        environment    = var.environment
    }
}

# Create public IPs for BIG-IP management UI
resource "azurerm_public_ip" "management_public_ip" {
    count               = length(var.azs)
    name                = format("%s-bigip-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static" # Static is required due to the use of the Standard sku
    sku                 = "Standard" # the Standard sku is required due to the use of availability zones
    zones               = [element(var.azs,count.index)]

    tags = {
        environment = var.environment
    }
}


# Create public IPs for JuiceShop
resource "azurerm_public_ip" "juiceshop_public_ip" {
    count               = length(var.azs)
    name                = format("%s-juiceshop-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static" # Static is required due to the use of the Standard sku
    sku                 = "Standard" # the Standard sku is required due to the use of availability zones
    zones               = [element(var.azs,count.index)]

    tags = {
        environment = var.environment
    }
}

# Create public IPs for Grafana
resource "azurerm_public_ip" "grafana_public_ip" {
    count               = length(var.azs)
    name                = format("%s-grafana-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static" # Static is required due to the use of the Standard sku
    sku                 = "Standard" # the Standard sku is required due to the use of availability zones
    zones               = [element(var.azs,count.index)]

    tags = {
        environment = var.environment
    }
}

# Setup Onboarding scripts
data "template_file" "vm_onboard" {
    template = "${file("${path.module}/onboard.tpl")}"

    vars = {
        uname       = var.admin_username
        # replace this with a reference to the secret id 
        upassword   = random_password.password.result
        DO_URL      = var.DO_URL
        AS3_URL     = var.AS3_URL
        TS_URL      = var.TS_URL
        libs_dir    = var.libs_dir
        onboard_log = var.onboard_log
    }
}