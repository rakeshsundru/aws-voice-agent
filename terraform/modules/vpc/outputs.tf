# =============================================================================
# VPC Module - Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].cidr_block : null
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].id : data.aws_subnets.private[0].ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = var.create_vpc ? aws_subnet.public[*].id : data.aws_subnets.public[0].ids
}

output "nat_gateway_ips" {
  description = "Public IPs of the NAT gateways"
  value       = var.create_vpc && var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = var.create_vpc ? aws_security_group.lambda[0].id : null
}

output "neptune_security_group_id" {
  description = "ID of the Neptune security group"
  value       = var.create_vpc ? aws_security_group.neptune[0].id : null
}

output "vpc_endpoint_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.create_vpc && var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint IDs"
  value = var.create_vpc && var.enable_vpc_endpoints ? {
    s3              = aws_vpc_endpoint.s3[0].id
    dynamodb        = aws_vpc_endpoint.dynamodb[0].id
    bedrock         = aws_vpc_endpoint.bedrock[0].id
    cloudwatch_logs = aws_vpc_endpoint.cloudwatch_logs[0].id
    secretsmanager  = aws_vpc_endpoint.secretsmanager[0].id
    lambda          = aws_vpc_endpoint.lambda[0].id
  } : {}
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.create_vpc ? aws_internet_gateway.main[0].id : null
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = var.create_vpc ? aws_route_table.private[*].id : []
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = var.create_vpc ? aws_route_table.public[0].id : null
}
