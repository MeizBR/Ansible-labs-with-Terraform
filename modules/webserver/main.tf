resource "aws_security_group" "sg" {
    name = "sg"
    vpc_id = var.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = var.ip_addresses_range
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-sg"
    }
}

data "aws_ami" "latest_ubuntu_image" {
    owners = ["099720109477"]
    filter {
        name = "name"
        values = [var.image_name]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

locals {
  serverconfig = [
    for srv in var.configuration : [
      for i in range(1, srv.no_of_instances+1) : {
        instance_name = "${srv.machine_name}-${i}"
      }
    ]
  ]
}

locals {
  instances = flatten(local.serverconfig)
}


resource "aws_instance" "aws_master_server" {
    ami = data.aws_ami.latest_ubuntu_image.id
    instance_type = var.instance_type

    subnet_id = var.subnet_id
    vpc_security_group_ids = [aws_security_group.sg.id]
    availability_zone = var.subnet_avail_zone

    associate_public_ip_address = true
    key_name = "ec2-instance-terraform"

    user_data = <<EOF
        #!/bin/bash
        echo "Changing the hostname to master"
        hostnamectl set-hostname master
        echo "127.0.0.1 master" >> /etc/hosts
        echo "Hostname changed successfully!"
    EOF

    tags = {
        Name: "master"
        Description: "ansible-labs-master"
    }
}

resource "aws_instance" "aws_clients_servers" {
    for_each = {for server in local.instances: server.instance_name =>  server}
    ami = data.aws_ami.latest_ubuntu_image.id
    instance_type = var.instance_type

    subnet_id = var.subnet_id
    vpc_security_group_ids = [aws_security_group.sg.id]
    availability_zone = var.subnet_avail_zone

    associate_public_ip_address = true
    key_name = "ec2-instance-terraform"

    user_data = <<EOF
        #!/bin/bash
        echo "Changing the hostname to ${each.value.instance_name}"
        hostnamectl set-hostname ${each.value.instance_name}
        echo "127.0.0.1 ${each.value.instance_name}" >> /etc/hosts
        echo "Hostname changed successfully!"
    EOF

    tags = {
        Name: "${each.value.instance_name}"
        Description: "ansible-labs-${var.env_prefix}"
    }
}