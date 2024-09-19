terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
    }
    http = {
      source = "hashicorp/http"
      version = "3.4.5"
    }
  }
}

resource "aws_security_group" "master_instance_sg" {
    depends_on = [data.http.icanhazip]

    name = "master_instance_sg"
    vpc_id = var.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.response_body)}/32"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8
        to_port = 0
        protocol = "icmp"
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
        Name: "${var.env_prefix}-master_instance_sg"
    }
}

resource "aws_security_group" "client_instances_sg" {
    name = "client_instances_sg"
    vpc_id = var.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8
        to_port = 0
        protocol = "icmp"
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
        Name: "${var.env_prefix}-client_instances_sg"
    }
}

data "aws_ami" "latest_amazon_linux_image" {
    owners = ["137112412989"]
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
    ami = data.aws_ami.latest_amazon_linux_image.id
    instance_type = var.instance_type

    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

    subnet_id = var.subnet_id
    vpc_security_group_ids = [aws_security_group.master_instance_sg.id]
    availability_zone = var.subnet_avail_zone

    associate_public_ip_address = true
    key_name = "ec2-instance-terraform"

    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file(var.private_key_location)
        host     = self.public_ip
    }

    # change hostname
    provisioner "file" {
        source = "./modules/webserver/scripts/change-hostname.sh"
        destination = "change-hostname-on-ec2.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x change-hostname-on-ec2.sh",
            "./change-hostname-on-ec2.sh"
        ]
    }

    # install ansible and disable host key checking
    provisioner "file" {
        source = "./modules/webserver/scripts/install-ansible.sh"
        destination = "install-ansible-on-ec2.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x install-ansible-on-ec2.sh",
            "./install-ansible-on-ec2.sh",
            "echo '[defaults]' | sudo tee /etc/ansible/ansible.cfg",
            "echo 'host_key_checking = False' | sudo tee -a /etc/ansible/ansible.cfg"
        ]
    }

    # enable username/password authentication
    provisioner "remote-exec" {
        inline = [
            "echo 'Enabling username/password authentication'",
            "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config",
            "echo 'ec2-user:${random_string.random_password.result}' | sudo chpasswd",
            "sudo systemctl restart sshd.service",
            "echo 'Username/password authentication successfully configured!'"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1",
            "sleep 2",
            "aws s3 cp ~/.ssh/id_rsa.pub s3://ansible-labs/id_rsa.pub"
        ]
    }

    tags = {
        Name: "master"
        Description: "ansible-labs-master-instances-group"
    }
}

resource "null_resource" "create_inventory_file" {
    provisioner "local-exec" {
        command = "echo '[webservers]' > ./hosts.ini"
    }
}

resource "aws_instance" "aws_clients_servers" {
    depends_on = [aws_instance.aws_master_server]

    for_each = {for server in local.instances: server.instance_name =>  server}
    ami = data.aws_ami.latest_amazon_linux_image.id
    instance_type = var.instance_type

    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

    subnet_id = var.subnet_id
    vpc_security_group_ids = [aws_security_group.client_instances_sg.id]
    availability_zone = var.subnet_avail_zone

    associate_public_ip_address = true
    key_name = "ec2-instance-terraform"

    connection {
        type     = "ssh"
        user     = "ec2-user"
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

    provisioner "remote-exec" {
        inline = [
            "sleep 2",
            "aws s3 cp s3://ansible-labs/id_rsa.pub ~/"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "sleep 5",
            "cat ~/id_rsa.pub >> ~/.ssh/authorized_keys"
        ]
    }

    provisioner "local-exec" {
        command = "echo '${self.public_ip} ansible_user=ec2-user' >> ./hosts.ini"
    }

    tags = {
        Name: "${each.value.instance_name}"
        Description: "ansible-labs-clients-instances-group"
    }
}

resource "null_resource" "fill_ansible_inventory" {
  depends_on = [aws_instance.aws_master_server, aws_instance.aws_clients_servers]

    connection {
        type     = "ssh"
        user     = "ec2-user"
        password = random_string.random_password.result
        host     = aws_instance.aws_master_server.public_ip
    }

    provisioner "file" {
        source = "./hosts.ini"
        destination = "hosts.ini"
    }

    provisioner "remote-exec" {
        inline = [
            "cat ~/hosts.ini | sudo tee -a /etc/ansible/hosts"
        ]
    }
}