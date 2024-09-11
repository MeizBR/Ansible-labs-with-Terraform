output "master_instance" {
    value = aws_instance.aws_master_server
    description = "EC2 master instance details"
}

output "clients_instances" {
    value = aws_instance.aws_clients_servers
    description = "EC2 clients instances details"
}