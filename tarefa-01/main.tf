terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

resource "azurerm_resource_group" "rg-impactacloud" {
  name     = "rg-${var.prefix}"
  location = var.location
}


resource "azurerm_virtual_network" "vnet-impactacloud" {
    name                = "vnet-${var.prefix}"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.rg-impactacloud.name
}

resource "azurerm_subnet" "sub-impactacloud" {
    name                 = "subnet-${var.prefix}"
    resource_group_name  = azurerm_resource_group.rg-impactacloud.name
    virtual_network_name = azurerm_virtual_network.vnet-impactacloud.name
    address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public-ip-impactacloud" {
    name                         = "public-ip-${var.prefix}"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.rg-impactacloud.name
    allocation_method            = "Dynamic"
}

data "azurerm_public_ip" "public-ip-impactaclouddata" {
  name                = azurerm_public_ip.public-ip-impactacloud.name
  resource_group_name = azurerm_public_ip.public-ip-impactacloud.resource_group_name
}

resource "azurerm_network_security_group" "sg-impactacloud" {
    name                = "sg-${var.prefix}"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg-impactacloud.name

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
        name                       = "HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "nci-impactacloud" {
    name                      = "nci-${var.prefix}"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.rg-impactacloud.name

    ip_configuration {
        name                          = "ipconfig-${var.prefix}"
        subnet_id                     = azurerm_subnet.sub-impactacloud.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.public-ip-impactacloud.id
    }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-impactacloud" {
    network_interface_id      = azurerm_network_interface.nci-impactacloud.id
    network_security_group_id = azurerm_network_security_group.sg-impactacloud.id
}


# Virtual Machine
resource "azurerm_storage_account" "sa-impactacloud" {
    name                        = "storageimpactacloud"
    resource_group_name         = azurerm_resource_group.rg-impactacloud.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_linux_virtual_machine" "vm-impactacloud" {
    name                  = "vm-${var.prefix}"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg-impactacloud.name
    size                  = "Standard_D2ads_v5"
    
    network_interface_ids = [azurerm_network_interface.nci-impactacloud.id]
    
    os_disk {
        name                 = "myappdisk"
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvmimpacta"
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false
    
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.public-ip-impactaclouddata.ip_address
        }
        
        inline = [
            "sudo apt update",
            "sudo apt install -y apache2",
        ]
    }
   
    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.sa-impactacloud.primary_blob_endpoint
    }

    depends_on = [ azurerm_resource_group.rg-impactacloud, azurerm_network_interface.nci-impactacloud, azurerm_storage_account.sa-impactacloud, azurerm_public_ip.public-ip-impactacloud ]
}