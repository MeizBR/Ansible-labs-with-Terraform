vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_block = "10.0.10.0/24"
region = "eu-west-3"
env_prefix = "dev"
subnet_avail_zone = "eu-west-3a"
ip_addresses_range = ["0.0.0.0/0"]
instance_type = "t2.micro"
image_name = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240701"

configuration = [
  {
    machine_name = "client",
    no_of_instances = "2"
  },
  
]

private_key_location = "/home/meiezbr/Downloads/ec2-instance-terraform.pem"