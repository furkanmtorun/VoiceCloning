output "main_vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet_1a_id" {
    value = aws_subnet.public_1a.id
}

output "private_subnet_1a_id" {
    value = aws_subnet.private_1a.id
}

output "private_subnet_1b_id" {
    value = aws_subnet.private_1b.id
}

output "security_group_for_batch_id" {
    value = aws_security_group.batch.id
}