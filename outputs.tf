# --- networking/outputs.tf ---

output "vpc-id" {
  value = aws_vpc.mtc-vpc.id
}

output "db-subnet-group-name" {
  value = aws_db_subnet_group.mtc-rds-subnetgroup.*.name
}

output "db-security-group" {
  value = aws_security_group.mtc-sg["rds"].id
}

output "public-sg" {
  value = aws_security_group.mtc-sg["public"].id
}

output "public-subnets" {
  value = aws_subnet.mtc-public-subnet.*.id
}
