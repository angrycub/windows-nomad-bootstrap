provider "aws" {
  region = "${var.region}"
}

# Lookup the correct AMI based on the region specified
data "aws_ami" "windows_2016" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-2019.05.15"]
  }
}

resource "aws_instance" "nomad_server" {
  ami             = "${data.aws_ami.windows_2016.id}"
  instance_type   = "t2.medium"
  key_name        = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.primary.id}"]
  count                  = "${var.server_count}"

  tags {
    Name           = "${var.name}-server-${count.index + 1}"
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
}

resource "aws_instance" "nomad_client" {
  ami             = "${data.aws_ami.windows_2016.id}"
  instance_type   = "t2.medium"
  key_name        = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.primary.id}"]
  count                  = "${var.server_count}"

  tags {
    Name           = "${var.name}-client-${count.index + 1}"
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
}