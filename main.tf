terraform {
    required_version = ">= 0.13"

    required_providers {
      azurerm = {
          source = "hashicorp/azurerm"
          version = ">= 2.26"
      }
    }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg-servidorapache" {
    name = "servidorapacheterra_victor"
    location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet-servidorapache" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-servidorapache.location
  resource_group_name = azurerm_resource_group.rg-servidorapache.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    atividade = "Servidor Apache 2"
  }
}

resource "azurerm_subnet" "sub-servidorapache" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-servidorapache.name
  virtual_network_name = azurerm_virtual_network.vnet-servidorapache.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-servidorapache" {
  name                    = "publicip"
  location                = azurerm_resource_group.rg-servidorapache.location
  resource_group_name     = azurerm_resource_group.rg-servidorapache.name
  allocation_method       = "Static"
}

resource "azurerm_network_security_group" "nsg-servidorapache" {
  name                = "nsg"
  location            = azurerm_resource_group.rg-servidorapache.location
  resource_group_name = azurerm_resource_group.rg-servidorapache.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic-servidorapache" {
  name                = "nic"
  location            = azurerm_resource_group.rg-servidorapache.location
  resource_group_name = azurerm_resource_group.rg-servidorapache.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.sub-servidorapache.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-servidorapache.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-servidorapache" {
  network_interface_id      = azurerm_network_interface.nic-servidorapache.id
  network_security_group_id = azurerm_network_security_group.nsg-servidorapache.id
}

resource "azurerm_storage_account" "sa-servidorapache" {
  name                     = "saservidorapache"
  resource_group_name      = azurerm_resource_group.rg-servidorapache.name
  location                 = azurerm_resource_group.rg-servidorapache.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine" "vm-servidorapache" {
  name                = "vmservidorapache"
  resource_group_name = azurerm_resource_group.rg-servidorapache.name
  location            = azurerm_resource_group.rg-servidorapache.location
  size                = "Standard_E2bs_v5"
  network_interface_ids = [
    azurerm_network_interface.nic-servidorapache.id,
  ]

  admin_username      = var.user
  admin_password      = var.password
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
      name = "mydisk"
      caching = "ReadWrite"
      storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
      storage_account_uri = azurerm_storage_account.sa-servidorapache.primary_blob_endpoint
  }

}

data "azurerm_public_ip" "ip-servidorapache-data" {
    name = azurerm_public_ip.ip-servidorapache.name
    resource_group_name = azurerm_resource_group.rg-servidorapache.name
}

variable user {
    description = "usuário da máquina"
    type = string
}

variable "password" {
    description = "senha da máquina"
    type = string
}

resource "null_resource" "install-webserver" {
  connection {
    type= "ssh"
    host = data.azurerm_public_ip.ip-servidorapache-data.ip_address
    user = var.user
    password = var.password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
      azurerm_linux_virtual_machine.vm-servidorapache
  ]
}