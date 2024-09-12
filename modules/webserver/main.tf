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

    connection {
        type     = "ssh"
        user     = "ubuntu"
        private_key = file(var.private_key_location)
        host     = self.public_ip
    }

    # change hostname
    provisioner "file" {
        source = "/home/meiezbr/Desktop/ansible-labs-with-terraform-freelance-project/modules/webserver/change-hostname.sh"
        destination = "/home/ubuntu/change-hostname-on-ec2.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /home/ubuntu/change-hostname-on-ec2.sh",
            "/home/ubuntu/change-hostname-on-ec2.sh"
        ]
    }

    #sleep 5 seconds before proceeding to ansible installation
    provisioner "remote-exec" {
        inline = [
            "sleep 5"
        ]
    }

    # install ansible
    provisioner "file" {
        source = "/home/meiezbr/Desktop/ansible-labs-with-terraform-freelance-project/modules/webserver/install-ansible.sh"
        destination = "/home/ubuntu/install-ansible-on-ec2.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /home/ubuntu/install-ansible-on-ec2.sh",
            "/home/ubuntu/install-ansible-on-ec2.sh"
        ]
    }

    provisioner "local-exec" {
        command = "echo 'This is the ec2 master instance public ip : ${self.public_ip}' > master_ip_output.txt"
    }

    tags = {
        Name: "master"
        Description: "ansible-labs-master-instances-group"
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

    connection {
        type     = "ssh"
        user     = "ubuntu"
        private_key = file(var.private_key_location)
        host     = self.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "echo 'Changing the hostname to ${each.value.instance_name}'",
            "sudo hostnamectl set-hostname ${each.value.instance_name}",
            "echo '${each.value.instance_name}' | sudo tee /etc/hostname",
            "echo '127.0.0.1 ${each.value.instance_name}' | sudo tee -a /etc/hosts",
            "echo 'Hostname changed successfully!'"
        ]
    }

    provisioner "local-exec" {
        command = "echo 'this another ec2 client instance public ip : ${self.public_ip}' >> clients_ip_output.txt"
    }

    tags = {
        Name: "${each.value.instance_name}"
        Description: "ansible-labs-clients-instances-group"
    }
}