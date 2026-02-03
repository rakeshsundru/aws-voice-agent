# =============================================================================
# Connect Module - Outputs
# =============================================================================

output "instance_id" {
  description = "ID of the Connect instance"
  value       = local.instance_id
}

output "instance_arn" {
  description = "ARN of the Connect instance"
  value       = local.instance_arn
}

output "instance_alias" {
  description = "Alias of the Connect instance"
  value       = local.create_instance ? aws_connect_instance.main[0].instance_alias : var.instance_alias
}

output "phone_number" {
  description = "Phone number assigned to the Connect instance"
  value       = var.claim_phone_number ? aws_connect_phone_number.main[0].phone_number : null
}

output "phone_number_id" {
  description = "ID of the phone number"
  value       = var.claim_phone_number ? aws_connect_phone_number.main[0].id : null
}

output "phone_number_arn" {
  description = "ARN of the phone number"
  value       = var.claim_phone_number ? aws_connect_phone_number.main[0].arn : null
}

output "contact_flow_id" {
  description = "ID of the inbound contact flow"
  value       = aws_connect_contact_flow.inbound.contact_flow_id
}

output "contact_flow_arn" {
  description = "ARN of the inbound contact flow"
  value       = aws_connect_contact_flow.inbound.arn
}

output "queue_id" {
  description = "ID of the main queue"
  value       = aws_connect_queue.main.queue_id
}

output "queue_arn" {
  description = "ARN of the main queue"
  value       = aws_connect_queue.main.arn
}

output "routing_profile_id" {
  description = "ID of the routing profile"
  value       = aws_connect_routing_profile.main.routing_profile_id
}

output "routing_profile_arn" {
  description = "ARN of the routing profile"
  value       = aws_connect_routing_profile.main.arn
}

output "hours_of_operation_id" {
  description = "ID of the hours of operation"
  value       = aws_connect_hours_of_operation.main.hours_of_operation_id
}

output "hours_of_operation_arn" {
  description = "ARN of the hours of operation"
  value       = aws_connect_hours_of_operation.main.arn
}

output "service_role" {
  description = "Service role ARN for the Connect instance"
  value       = local.create_instance ? aws_connect_instance.main[0].service_role : null
}

output "connect_url" {
  description = "URL of the Connect instance"
  value       = local.create_instance ? "https://${aws_connect_instance.main[0].instance_alias}.my.connect.aws" : "https://${var.instance_alias}.my.connect.aws"
}
