variable "server_name" {
    type = string
    default = "web-server"
}


variable "bootstrap" {
  description = "The bootstrap server (ie: lkc-9nzg7-4ny96.northeurope.azure.glb.confluent.cloud:9092)"
  type        = string
  default     = "lkc-9nzg7-4ny96.northeurope.azure.glb.confluent.cloud:9092"
}

variable "privatelink_service_alias_by_zone" {
  description = "A map of Zone to Service Alias from Confluent Cloud to Private Link with (provided by Confluent)"
  type        = map(string)
}
