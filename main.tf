#require provider to main VM
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

}
#auth automatic allow
provider "azurerm" {
  skip_provider_registration = true
   features {}
}


# rg
resource "azurerm_resource_group" "rg-aulainfra" {
  name     = "rgAulainfra"
  location = "eastus"
}

# vlan
resource "azurerm_virtual_network" "vnet-aulainfra" {
  name                = "vnetAula"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  address_space       = ["10.4.0.0/16"]
  
depends_on = [ azurerm_resource_group.rg-aulainfra ]
  
}
# subnet
resource "azurerm_subnet" "sbn-aula" {
  name                 = "sbnAula"
  resource_group_name  = azurerm_resource_group.rg-aulainfra.name
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  address_prefixes     = ["10.4.0.0/16"]

depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_virtual_network.vnet-aulainfra ]
 
}

# external IP
resource "azurerm_public_ip" "pi-aula" {
  name                = "piAula"
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  location            = azurerm_resource_group.rg-aulainfra.location
  allocation_method   = "Static"
}

# ni
resource "azurerm_network_interface" "ni-aula" {
  name                = "niAula"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sbn-aula.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.4.4.16"
    public_ip_address_id = azurerm_public_ip.pi-aula.id
  }

depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_subnet.sbn-aula, azurerm_public_ip.pi-aula ]

}

resource "azurerm_storage_account" "storage-aula2" {
    name                        = "storageaula2"
    resource_group_name         = azurerm_resource_group.rg-aulainfra.name
    location                    = azurerm_resource_group.rg-aulainfra.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}


resource "azurerm_linux_virtual_machine" "db-provider-vm" {
    name                  = "db-provider"
    location              = azurerm_resource_group.rg-aulainfra.location
    resource_group_name   = azurerm_resource_group.rg-aulainfra.name
    network_interface_ids = [azurerm_network_interface.ni-aula.id]
    size                  = "Standard_DS1_V2"

    os_disk {
        name              = "dbProviderDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "dbProvider"
    admin_username      = "sysadmin"
    admin_password      = "@dmin102030"
    disable_password_authentication = false

    depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_network_interface.ni-aula, azurerm_storage_account.storage-aula2, azurerm_public_ip.pi-aula ]
}

resource "null_resource" "resource_prv" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "sysadmin"
            password = "@dmin102030"
            host = azurerm_public_ip.pi-aula.ip_address
        }
        source = "mysql"
        destination = "/home/sysadmin"
    }
}

resource "null_resource" "install_db" {
  triggers = {
    order = null_resource.resource_prv.id
  }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user =   "adminuser"
            password = "Aula@infra02"
            host = azurerm_public_ip.pi-aula.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo cp -f /home/adminuser/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "echo config works !",
        ]
    }
}