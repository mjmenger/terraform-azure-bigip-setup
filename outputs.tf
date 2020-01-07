output "config" {
    value = data.azurerm_client_config.current
}

output "bigip_mgmt_public_ips" {
    value = azurerm_public_ip.management_public_ip[*].ip_address
}

output "bigip_mgmt_port" {
    value = "443"
}

output "bigip_password" {
    value = random_password.password.result
}

output "ec2_key_name" {
    value = var.privatekeyfile
}

output "jumphost_ip" {
    value = azurerm_public_ip.jh_public_ip[*].ip_address
}

output "juiceshop_ip" {
    value = azurerm_public_ip.juiceshop_public_ip[*].ip_address
}

output "grafana_ip" {
    value = azurerm_public_ip.grafana_public_ip[*].ip_address
}