provider "aws" {
    region = var.region
}

resource "aws_s3_bucket" "ansible_labs" {
  bucket = "ansible-labs"
  force_destroy = true

  tags = {
    Name: "${var.env_prefix}-ansible_labs_s3_bucket"
  }
}

resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

module "subnet" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block
    subnet_avail_zone = var.subnet_avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.vpc.id
}

module "webserver" {
    source = "./modules/webserver"
    ip_addresses_range = var.ip_addresses_range
    image_name = var.image_name
    instance_type = var.instance_type
    subnet_id = module.subnet.subnet.id
    subnet_avail_zone = var.subnet_avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.vpc.id
    configuration = var.configuration
    key_name = var.key_name
    private_key_location = var.private_key_location
    os = var.os
}
