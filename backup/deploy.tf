# MICROSOFT AZURE PROVIDER
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# RESOURCE GROUP
resource "azurerm_resource_group" "armrg" {
    name     			= "HashiCorpTechExercise"
    location 			= "${var.location}"

    tags {
        environment = "Tech Exercise"
    }
}

# VIRTUAL NETWORK
resource "azurerm_virtual_network" "armnetwork" {
    name                = "Virtual Network"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.armrg.name}"

    tags {
        environment = "Tech Exercise"
    }
}

# SUBNET
resource "azurerm_subnet" "armsubnet" {
    name                 = "Default Subnet"
    resource_group_name  = "${azurerm_resource_group.armrg.name}"
    virtual_network_name = "${azurerm_virtual_network.armnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# PUBLIC IP ADDRESSES
resource "azurerm_public_ip" "armpip" {
    name                         = "${azurerm_virtual_machine.armvm.name}"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.armrg.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Tech Exercise"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "armnsg" {
    name                = "Allow-SSH-NSG"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.armrg.name}"

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

    tags {
        environment = "Tech Exercise"
    }
}

# Create network interface
resource "azurerm_network_interface" "armnic" {
    name                      = "${azurerm_virtual_machine.armvm.name}"
    location                  = "${var.location}"
    resource_group_name       = "${azurerm_resource_group.armrg.name}"
    network_security_group_id = "${azurerm_network_security_group.armnsg.id}"

    ip_configuration {
        name                          = "ipconfig"
        subnet_id                     = "${azurerm_subnet.armsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.armpip.id}"
    }

    tags {
        environment = "Tech Exercise"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.armrg.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "armdiag" {
    name                        = "diagnostics${random_id.id.hex}"
    resource_group_name         = "${azurerm_resource_group.armrg.name}"
    location                    = "${var.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Tech Exercise"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "armvm" {
    name                  = "${var.vmprefix}-osdisk"
    location              = "${var.location}"
    resource_group_name   = "${azurerm_resource_group.armrg.name}"
    network_interface_ids = ["${azurerm_network_interface.armnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "${var.vmprefix}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.vmprefix}-osdisk"
        admin_username = "adminuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.armdiag.primary_blob_endpoint}"
    }

    tags {
        environment = "Tech Exercise"
    }
}