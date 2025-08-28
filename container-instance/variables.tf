# General vCenter data
variable "vsphere_conf" {
  type = list(object({
    vsphere_server      = string
    vsphere_user        = string
    vsphere_password    = string
    datacenter          = string
    datastore           = string
    resource_pool       = string
    esxi_host           = string
    template            = string
    network             = string
  }))
}

# Network configuration data
variable "vpc_cidr" {}
variable "consul_domain" {}
variable "dns_server" {
    default = "8.8.8.8"
}

# Virtual Machine configuration
variable "name" {}
variable "cpu" {}
variable "memory" {}
variable "ssh_key" {}
variable "system_disk_size" {
    default = 20
}
variable "data_disk_size" {
    default = 100
}
variable "disk_io" {
    default = 1000
}