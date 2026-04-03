# subnet_id sẽ được truyền sang compute module — các server cần biết subnet nào để gắn VPC interface

output "vpc_id" {
  value = linode_vpc.main.id
}

output "subnet_id" {
  value = linode_vpc_subnet.app.id
}