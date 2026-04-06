terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id                 = "444b0153-163f-4ff5-8ca8-e99dd055fc34"
  resource_provider_registrations = "none"
  features {}
}

data "azurerm_resource_group" "existing" {
  name = "azure-network-components"
}

resource "azurerm_virtual_network" "application_deployment_vnet" {
  name                = "application-deployment-vnet"
  location            = "Germany West Central"
  resource_group_name = data.azurerm_resource_group.existing.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public_subnet"
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.application_deployment_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

variable "vm_admin_password" {
  description = "Admin password for the Ubuntu VM. Must meet Azure complexity requirements."
  type        = string
  sensitive   = true
}

resource "azurerm_public_ip" "application_deployment_vm_public_ip" {
  name                = "application-deployment-vm-public-ip"
  location            = "Germany West Central"
  resource_group_name = data.azurerm_resource_group.existing.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "application_deployment_vm_nsg" {
  name                = "application-deployment-vm-nsg"
  location            = "Germany West Central"
  resource_group_name = data.azurerm_resource_group.existing.name

  security_rule {
    name                       = "allow-ssh-22"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http-80"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-app-5000"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-mysql-3306"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "application_deployment_vm_nic" {
  name                = "application-deployment-vm-nic"
  location            = "Germany West Central"
  resource_group_name = data.azurerm_resource_group.existing.name

  ip_configuration {
    name                          = "application-deployment-vm-ipconfig"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.application_deployment_vm_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "application_deployment_vm" {
  network_interface_id      = azurerm_network_interface.application_deployment_vm_nic.id
  network_security_group_id = azurerm_network_security_group.application_deployment_vm_nsg.id
}

resource "azurerm_linux_virtual_machine" "application_deployment_vm" {
  name                = "application-deployment-vm"
  location            = "Germany West Central"
  resource_group_name = data.azurerm_resource_group.existing.name
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  admin_password      = var.vm_admin_password
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.application_deployment_vm_nic.id]
  priority            = "Regular"
  secure_boot_enabled = true
  vtpm_enabled        = true

  os_disk {
    name                 = "application-deployment-vm-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = null
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  tags = {
    Name = "application-deployment-vm"
  }
}
