vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_block = "10.0.10.0/24"
region = "eu-west-3"
env_prefix = "prod"
subnet_avail_zone = "eu-west-3a"
ip_addresses_range = ["0.0.0.0/0"]
instance_type = "t2.micro"
image_name = "al2023-ami-2023.5.20240903.0-kernel-6.1-x86_64"

configuration = [
  {
    machine_name = "client",
    no_of_instances = "2"
  }
]

private_key_location = "~/.ssh/ec2-instance-terraform.pem"