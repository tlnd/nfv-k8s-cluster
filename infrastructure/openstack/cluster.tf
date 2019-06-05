variable "name_prefix" {}
variable "instance_keypair" {}

variable "availability_zones" {
  default = {
    "0" = "local_zone_01"
    "1" = "local_zone_02"
    "2" = "local_zone_03"
  }
}

# master
variable "mastercount" {
  default = 1
}
resource "openstack_compute_instance_v2" "master" {
  count           = "${var.mastercount}"
  name            = "${format("%s-master-%02d", var.name_prefix, count.index+1)}"
  image_name      = "ubuntu-16.04-image"
  flavor_name     = "x1.small"
  key_pair        = "${var.instance_keypair}"
  security_groups = ["all_traffic"]
  availability_zone = "${lookup(var.availability_zones, count.index % length(var.availability_zones))}"

  network {
    name = "shared"
  }

  network {
    name = "uplink"
  }

  network {
    name = "${openstack_networking_network_v2.cluster-network.name}"
  }

#  connection {
#    user = "ubuntu"
#    type = "ssh"
#    timeout = "2m"
#    host = "${self.access_ip_v4}"
#  }
#
#	provisioner "file" {
#		source = "libexec/iface-config.sh"
#		destination = "/tmp/iface-config.sh"
#	}
#	provisioner "remote-exec" {
#		inline = [
#			"sudo sed -i 's/^root:.:/root:ADAHBG3GsnVKU:/' /etc/shadow",
#			"sudo chmod 0700 /tmp/iface-config.sh",
#			"sudo /tmp/iface-config.sh --udev shared0 ${self.network.0.mac}",
#			"sudo /tmp/iface-config.sh --udev uplink0 ${self.network.1.mac}",
#			"sudo /tmp/iface-config.sh --udev cluster0 ${self.network.2.mac}",
#			"sudo /tmp/iface-config.sh --ipconfig shared0 dhcp",
#			"sudo /tmp/iface-config.sh --ipconfig uplink0 dhcp",
#			"sudo /tmp/iface-config.sh --ipconfig cluster0 dhcp",
#			"sudo reboot"
#		]
#	}
#
#	provisioner "remote-exec" {
#		inline = [
#			"export PATH=$PATH:/usr/bin",
#			"sudo apt-get -y update",
#			"sudo apt-get -y install python2.7",
#			"sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1",
#		]
#	}
}

# worker nodes
variable "workercount" {
  default = 3
}
resource "openstack_compute_instance_v2" "worker" {
  count           = "${var.workercount}"
  name            = "${format("%s-worker-%02d", var.name_prefix, count.index+1)}"
  image_name      = "ubuntu-16.04-image"
  flavor_name     = "x1.small"
  key_pair        = "${var.instance_keypair}"
  security_groups = ["all_traffic"]
  availability_zone = "${lookup(var.availability_zones, count.index % length(var.availability_zones))}"

  network {
    name = "shared"
  }

  network {
    name = "uplink"
  }

  network {
    name = "${openstack_networking_network_v2.cluster-network.name}"
  }

  connection {
    user = "ubuntu"
    type = "ssh"
    timeout = "2m"
    host = "${self.access_ip_v4}"
  }

	provisioner "file" {
		source = "libexec/iface-config.sh"
		destination = "/tmp/iface-config.sh"
	}
	provisioner "remote-exec" {
		inline = [
			"sudo sed -i 's/^root:.:/root:ADAHBG3GsnVKU:/' /etc/shadow",
			"sudo chmod 0700 /tmp/iface-config.sh",
			"sudo /tmp/iface-config.sh --udev shared0 ${self.network.0.mac}",
			"sudo /tmp/iface-config.sh --udev uplink0 ${self.network.1.mac}",
			"sudo /tmp/iface-config.sh --udev cluster0 ${self.network.2.mac}",
			"sudo /tmp/iface-config.sh --udev dp0 ${openstack_networking_port_v2.port[count.index].mac_address}",
			"sudo /tmp/iface-config.sh --ipconfig shared0 dhcp",
			"sudo /tmp/iface-config.sh --ipconfig uplink0 dhcp",
			"sudo /tmp/iface-config.sh --ipconfig cluster0 dhcp",
			"sudo shutdown -r +0"
		]
	}
#
#	provisioner "remote-exec" {
#		inline = [
#			"export PATH=$PATH:/usr/bin",
#			"sudo apt-get -y update",
#			"sudo apt-get -y install python2.7",
#			"sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1",
#		]
#	}
}

resource "openstack_networking_port_v2" "port" {
  count           = "${var.workercount}"
  name            = "${format("%s-worker-port-%02d", var.name_prefix, count.index+1)}"
  network_id      = "${openstack_networking_network_v2.underlay-network.id}"
  no_security_groups = "true"
  no_fixed_ip = "true"
  port_security_enabled = "false"
}

resource "openstack_compute_interface_attach_v2" "attach" {
  count           = "${var.workercount}"
  instance_id = "${openstack_compute_instance_v2.worker.*.id[count.index]}"
  port_id  = "${openstack_networking_port_v2.port.*.id[count.index]}"
}

resource "openstack_networking_network_v2" "cluster-network" {
  name = "${var.name_prefix}-cluster-network"
  admin_state_up = "true"
}

resource "openstack_networking_network_v2" "underlay-network" {
  name = "${var.name_prefix}-underlay-network"
  admin_state_up = "true"
  #port_security_enabled = "false"
}

variable "cluster_cidr" {
  default = "10.77.0.0/18"
}

variable "underlay_cidr" {
  default = "10.78.0.0/18"
}

resource "openstack_networking_subnet_v2" "cluster-network" {
  name = "${var.name_prefix}-cluster-network"
  network_id = "${openstack_networking_network_v2.cluster-network.id}"
  cidr = "${var.cluster_cidr}"
  ip_version = 4
  no_gateway = "true"
}

resource "openstack_networking_subnet_v2" "underlay-network" {
  name = "${var.name_prefix}-underlay-network"
  network_id = "${openstack_networking_network_v2.underlay-network.id}"
  cidr = "${var.underlay_cidr}"
  ip_version = 4
  no_gateway = "true"
}
