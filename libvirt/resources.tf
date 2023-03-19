resource "libvirt_pool" "storagepool" {
  name = var.clustername
  type = "dir"
  path = "/var/lib/libvirt/${var.clustername}"
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  count          = length(local.hostnames)
  name           = "${local.hostnames[count.index]}-cloudinit.iso"
  meta_data      = templatefile("${path.module}/cloudinit/meta-data.tpl",
                                 {
                                   hostname    = local.hostnames[count.index]
                                 }
                               )
  user_data      = templatefile("${path.module}/cloudinit/user-data.tpl",
                                 {
                                   token       = var.token
                                   clustername = "${var.clustername}"
                                   latitude    = "${var.latitude}"
                                   longitude   = "${var.longitude}"
                                   hostname    = local.hostnames[count.index]
                                 }
                               )
  pool = libvirt_pool.storagepool.name
}

resource "libvirt_volume" "volume" {
  count  = length(local.hostnames)
  name   = "${local.hostnames[count.index]}.qcow2"
  pool   = libvirt_pool.storagepool.name
  source = var.qcow2
  format = "qcow2"
}

resource "libvirt_domain" "kvm-app-stack" {
  count      = length(local.hostnames)
  name       = local.hostnames[count.index]
  memory     = var.memory
  vcpu       = var.cpu
  qemu_agent = false
  autostart  = true
  arch = "x86_64"

  xml {
    xslt = templatefile("${path.module}/machine.xsl", {})
  }

  disk {
    volume_id    = element(libvirt_volume.volume[*].id, count.index)
  }

  cloudinit = element(libvirt_cloudinit_disk.cloudinit[*].id, count.index)

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    macvtap      = "enp109s0"
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}
