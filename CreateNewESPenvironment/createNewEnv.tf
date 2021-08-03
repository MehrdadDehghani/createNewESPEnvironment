 
terraform {
  required_version = ">= 0.13"
}

provider "azurerm" {
  features {
  }
  version = "~> 2.66.0"
  skip_provider_registration = true
}

locals {
  hosted_zone = replace(regex("^[^.]+-([0-9a-zA-Z]+[.].*):[0-9]+$", var.bootstrap)[0], "glb.", "")
  network_id = regex("^([^.]+)[.].*", local.hosted_zone)[0]
}

/*locals {
  assert_no_network_policies_enabled = length([
    for _, subnet in azurerm_virtual_network.vnet.subnet:
    true if !subnet.enforce_private_link_endpoint_network_policies
  ]) > 0 ? file("\n\nerror: private link endpoint network policies must be disabled https://docs.microsoft.com/en-us/azure/private-link/disable-private-endpoint-network-policy") : ""
}*/

resource "azurerm_resource_group" "rgterraform" {
  name     = "rg-terraform2"
  location = "North Europe"
}

/*resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-for-vnet-subnet-mm"
  location            = azurerm_resource_group.rgterraform.location
  resource_group_name = azurerm_resource_group.rgterraform.name
}*/

resource "azurerm_network_ddos_protection_plan" "ddospplan" {
  name                = "ddos-protection-plan"
  location            = azurerm_resource_group.rgterraform.location
  resource_group_name = azurerm_resource_group.rgterraform.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  resource_group_name = azurerm_resource_group.rgterraform.name
  location            = azurerm_resource_group.rgterraform.location
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.ddospplan.id
    enable = true
  }

  tags = {
    environment = "PreProduktion"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rgterraform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
enforce_private_link_endpoint_network_policies = true
  //enforce_private_link_service_network_policies = false
  /*  subnet_enforce_private_link_endpoint_network_policies = {
    azurerm_subnet.subnet.name = false
  }*/
}

output "resourceGroupName" {
    description = "Provisioned resource group name"
    value = "${azurerm_resource_group.rgterraform.name}"
}
output "resourceGroupId" {
    description = "Id for the resource group"
    value = "${azurerm_resource_group.rgterraform.id}"
}

output "vnetName" {
    description = "Name of the Virtual Network"
    value = "${azurerm_virtual_network.vnet.name}"
}
output "vnetId" {
    description = "Id of the Virtual Network"
    value = "${azurerm_virtual_network.vnet.id}"
}

output "subnetNames" {
    description = "Name of the subnet"    
//    value = "${azurerm_virtual_network.vnet.subnet[*].name}" for at skrive alle 3 subnet names ud
    value = "${(azurerm_subnet.subnet.name)}"
}
output "subnetId" {
    description = "Id for subnets"
    value = "${azurerm_subnet.subnet.id}"
}

resource "azurerm_private_dns_zone" "hz" {
  resource_group_name = azurerm_resource_group.rgterraform.name
  name = local.hosted_zone
}

resource "azurerm_private_dns_zone_virtual_network_link" "hz" {
  name                  = azurerm_virtual_network.vnet.name
  resource_group_name   = azurerm_resource_group.rgterraform.name
  private_dns_zone_name = azurerm_private_dns_zone.hz.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

output "hostedZoneName" {
    description = "Name of hosted zone"
    value = "${azurerm_private_dns_zone.hz.name}"
}


/*resource "azurerm_private_endpoint" "endpoint" {
    
  for_each = var.privatelink_service_alias_by_zone

  name                = "confluent-${local.network_id}-${each.key}"
  location            = azurerm_resource_group.rgterraform.location
  resource_group_name = azurerm_resource_group.rgterraform.name

  subnet_id = azurerm_virtual_network.vnet.subnet[each.key].id
  //subnet_id = azurerm_virtual_network.vnet.subnet[tonumber(each.key)-1].id
  //subnet_id = (azurerm_virtual_network.vnet.subnet[*].id)[tonumber(each.key)-1]
  
  private_service_connection {
    name                              = "confluent-${local.network_id}-${each.key}"
    is_manual_connection              = true
    private_connection_resource_alias = each.value
    request_message                   = "PL"
  }
}*/

resource "azurerm_private_endpoint" "endpoint1" {
    
  name                = "confluent-${local.network_id}-${"1"}"
  location            = azurerm_resource_group.rgterraform.location
  resource_group_name = azurerm_resource_group.rgterraform.name

  subnet_id = azurerm_subnet.subnet.id
  //subnet_id = azurerm_virtual_network.vnet.subnet[tonumber(each.key)-1].id
  //subnet_id = (azurerm_virtual_network.vnet.subnet[*].id)[tonumber(each.key)-1]
  
  private_service_connection {
    name                              = "confluent-${local.network_id}-${"1"}"
    is_manual_connection              = true
    private_connection_resource_alias = "s-nm36j-privatelink-3.c2ce345a-1fd7-4d44-af27-6df1f19062f7.northeurope.azure.privatelinkservice"
    request_message                   = "PL"
  }
}

output "localNetWorkId" {
    description = "localNetWorkId"
    value = "${local.network_id}" 
    //-${azurerm_private_endpoint.privateEndpoints.subnet_id[0].subnet_id}-${azurerm_private_endpoint.privateEndpoints.private_service_connection[0].name}"
}

resource "azurerm_container_group" "example" {
  name                = "example-continst"
  location            = azurerm_resource_group.rgterraform.location
  resource_group_name = azurerm_resource_group.rgterraform.name
  ip_address_type     = "public"
  //dns_name_label      = "aci-label"
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "microsoft/aci-helloworld:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 443
      protocol = "TCP"
    }
  }

  tags = {
    environment = "testing"
  }
}