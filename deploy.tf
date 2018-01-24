# MICROSOFT AZURE PROVIDER
provider "azurerm" {}

# RESOURCE GROUP
resource "azurerm_resource_group" "armrg" {
    name     			= "${var.resourcegroupname}"
    location 			= "${var.location}"
    tags {
        environment = "${var.environment}"
    }
}

# VIRTUAL NETWORK
resource "azurerm_virtual_network" "armnetwork" {
    name                = "${var.environment}-vNet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.armrg.name}"

    tags {
        environment = "${var.environment}"
    }
}

# SUBNET
resource "azurerm_subnet" "armsubnet" {
    name                 = "Default"
    resource_group_name  = "${azurerm_resource_group.armrg.name}"
    virtual_network_name = "${azurerm_virtual_network.armnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# PUBLIC IP ADDRESSES
resource "azurerm_public_ip" "armpip" {
    count                        = "${var.count}"
    name                         = "${var.vmprefix}${count.index}-PIP"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.armrg.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "${var.environment}"
    }
}

# NETWORK SECURITY GROUP AND RULE
resource "azurerm_network_security_group" "armnsg" {
    name                = "Subnet-NSG"
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
        environment = "${var.environment}"
    }
}

# NETWORK INTERFACE
resource "azurerm_network_interface" "armnic" {
    count                     = "${var.count}"
    name                      = "${var.vmprefix}${count.index}-NIC"
    location                  = "${var.location}"
    resource_group_name       = "${azurerm_resource_group.armrg.name}"
    network_security_group_id = "${azurerm_network_security_group.armnsg.id}"

    ip_configuration {
        name                          = "ipconfig"
        subnet_id                     = "${azurerm_subnet.armsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${length(azurerm_public_ip.armpip.*.id) > 0 ? element(concat(azurerm_public_ip.armpip.*.id, list("")), count.index) : ""}"
    }

    tags {
        environment = "${var.environment}"
    }
}

# RANDOM ID
resource "random_id" "id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.armrg.name}"
    }

    byte_length = 8
}

# DIAGNOSTIC STORAGE ACCOUNT
resource "azurerm_storage_account" "armdiag" {
    name                        = "tacaeconsoldiage001"
    resource_group_name         = "${azurerm_resource_group.armrg.name}"
    location                    = "${var.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "${var.environment}"
    }
}

# AVAILABILITY SET
resource "azurerm_availability_set" "armav" {
    name                         = "${var.vmprefix}-AV"
    location                     = "${azurerm_resource_group.armrg.location}"
    resource_group_name          = "${azurerm_resource_group.armrg.name}"
    platform_fault_domain_count  = 2
    platform_update_domain_count = 2
    managed                      = true
    tags {
        environment = "${var.environment}"
    }
}

# VIRTUAL MACHINE
resource "azurerm_virtual_machine" "armvm" {
    count                               = "${var.count}"
    name                                = "${var.vmprefix}${count.index}"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.armrg.name}"
    network_interface_ids               = ["${element(azurerm_network_interface.armnic.*.id, count.index)}"]
    availability_set_id                 = "${azurerm_availability_set.armav.id}"
    vm_size                             = "${var.vmsize}"
    delete_os_disk_on_termination       = true
    delete_data_disks_on_termination    = true

    storage_os_disk {
        name              = "${var.vmprefix}${count.index}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.vmprefix}${count.index}"
        admin_username = "${var.user}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.armdiag.primary_blob_endpoint}"
    }

    tags {
        environment = "${var.environment}"
    }
}

# AZURE VM EXTENSION LINUX CUSTOM SCRIPT
resource "azurerm_virtual_machine_extension" "armext" {
    name                 = "LinuxScriptExtension"
    location             = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.armrg.name}"
    virtual_machine_name = "${var.vmprefix}${count.index}"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"
    depends_on           = ["azurerm_virtual_machine.armvm"]

    settings = <<SETTINGS
    {
        "commandToExecute": "sudo sh ./consul.sh ${var.count} ${element(azurerm_network_interface.armnic.*.private_ip_address, 0)} ${var.version}",
        "fileUris": ["https://raw.githubusercontent.com/ryanjhall/tfte/master/scripts/consul.sh"]
    }
    SETTINGS

    tags {
        environment = "${var.environment}"
    }
}

# OUTPUTS
output "public_ip" {
    value = "${azurerm_public_ip.armpip.*.id}"
}

output "private_ip" {
    value = "${element(azurerm_network_interface.armnic.*.private_ip_address, 0)}"
}

output "module_path" {
    value = "${path.module}"
}