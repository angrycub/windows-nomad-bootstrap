provider "aws" {
  region = "${var.region}"
  profile = "${var.profile}"
}

resource "aws_instance" "nomad_server" {
  ami             = "${var.ami}"
  instance_type   = "t2.large"
  key_name        = "${var.key_name}"
  get_password_data = true
  vpc_security_group_ids = ["${aws_security_group.primary.id}"]
  count                  = "${var.server_count}"
  tags {
    Name           = "${var.name}-win-nomad-server-${count.index + 1}"
  }

  root_block_device = {
    volume_size = "100"
  }

  ebs_block_device = {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = "true"
  }
  connection {
    type = "winrm"
    port = 5986
    password = "${rsadecrypt(self.password_data, file("${var.ssh_key}"))}"
    https = true
    insecure = true
  }
  provisioner "file" {
    source = "../scripts/setup.ps1"
    destination = "C:/"
  }
}

resource "aws_instance" "nomad_client" {
  ami             = "${var.ami}"
  instance_type   = "t2.medium"
  key_name        = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.primary.id}"]
  count                  = "${var.client_count}"

  tags {
    Name           = "${var.name}-win-nomad-client-${count.index + 1}"
  }

  root_block_device = {
    volume_size = "100"
  }

  ebs_block_device = {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
   volume_size           = "50"
    delete_on_termination = "true"
  }
  connection {
    type = "winrm"
    port = 5986
    password = "${rsadecrypt(self.password_data, file("${var.ssh_key}"))}"
    https = true
    insecure = true
    timeout = "15m"
  }
  provisioner "file" {
    source = "../scripts/setup.ps1"
    destination = "C:/"
  }    
}