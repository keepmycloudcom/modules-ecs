provider "vsphere" {
  user                  = lookup(var.vsphere_conf[0], "vsphere_user")
  password              = lookup(var.vsphere_conf[0], "vsphere_password")
  vsphere_server        = lookup(var.vsphere_conf[0], "vsphere_server")

  allow_unverified_ssl  = true
}

data "vsphere_host" "host" {
  name          = lookup(var.vsphere_conf[0], "esxi_host")
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datacenter" "dc" {
  name = lookup(var.vsphere_conf[0], "datacenter")
}

data "vsphere_datastore" "datastore" {
  name          = lookup(var.vsphere_conf[0], "datastore")
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = lookup(var.vsphere_conf[0], "resource_pool")
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = lookup(var.vsphere_conf[0], "network")
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "template_file" "script" {
  template = "${file("${path.module}/cloud-init/userdata.yaml")}"

  vars = {
    consul_domain = "${var.consul_domain}"
    vpc_cidr = "${var.vpc_cidr}"
    gw = cidrhost(var.vpc_cidr, 1)
    dns = "${var.dns_server}"
  }
}

## Deployment of VM from Remote OVF
resource "vsphere_virtual_machine" "vmFromRemoteOvf" {
  name             = "${var.name}"
  num_cpus         = "${var.cpu}"
  memory           = "${var.memory}"
  datacenter_id    = data.vsphere_datacenter.dc.id
  datastore_id     = data.vsphere_datastore.datastore.id
  host_system_id   = data.vsphere_host.host.id
  resource_pool_id = data.vsphere_resource_pool.pool.id

  wait_for_guest_net_timeout = 30
  wait_for_guest_ip_timeout  = 30

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = lookup(var.vsphere_conf[0], "template")
    ovf_network_map = {
      "VM Network" = data.vsphere_network.network.id
    }
  }
  cdrom {
    client_device = true
  }
  disk {
    label       = "${var.name}-system"
    size        = "${var.system_disk_size}"
    io_share_count = "${var.disk_io}"
    thin_provisioned = false

  }
  disk {
    label       = "${var.name}-data"
    size        = "${var.data_disk_size}"
    io_share_count = "${var.disk_io}"
    unit_number = 1
  }
  vapp {
    properties = {
      "hostname"  = "${var.name}",
      "instance-id" = "${var.name}",
      "public-keys" = "${var.ssh_key}",
      "user-data" = base64encode("${data.template_file.script.rendered}")
    }
  }
}

### Outputs
output "vm_ip" { value = vsphere_virtual_machine.vmFromRemoteOvf.default_ip_address  }

# vim:filetype=terraform ts=2 sw=2 et:
