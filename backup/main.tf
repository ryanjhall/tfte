variable subscription_id { default = "349de0f4-29e2-48fe-9cc7-80313a827e26" } 
variable client_id { default = "60cbc59a-03aa-4804-b84a-2ca48b966f0e" }
variable client_secret { default = "8f2397fb-a0f9-4cf9-a5a7-74ad126a5096" }
variable tenant_id { default = "5a4d91a0-4198-4e36-8f43-01649652e1e5"}
variable location { default = "Australia East" }
variable count { default = 3 }
variable vmprefix { default = "CONSULVM" }
variable resourcegroupname { default = "Consul-Cluster-Services"}

# MICROSOFT AZURE PROVIDER
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# UBUNTU CLUSTER
module "compute" {
    source              = "Azure/compute/azurerm"
    resource_group_name = "${var.resourcegroupname}"
    location            = "${var.location}"
    vm_hostname         = "${var.vmprefix}"
    nb_public_ip        = "0"
    remote_port         = "22"
    nb_instances        = "${var.count}"
    vm_os_publisher     = "Canonical"
    vm_os_offer         = "UbuntuServer"
    vm_os_sku           = "14.04.2-LTS"
    vnet_subnet_id      = "${module.network.vnet_subnets[0]}"
    boot_diagnostics    = "true"
    delete_os_disk_on_termination = "true"
    data_disk           = "false"
    data_disk_size_gb   = "64"
    data_sa_type        = "Premium_LRS"
}

module "network" {
    source = "Azure/network/azurerm"
    location = "${var.location}"
    resource_group_name = "${var.resourcegroupname}"
}

output "vm_ids" { value = "${module.compute.vm_ids}" }
output "vm_public_name" { value = "${module.compute.public_ip_dns_name}" }
output "vm_public_ip" { value = "${module.compute.public_ip_address}" }
output "vm_private_ips" { value = "${module.compute.network_interface_private_ip}" }