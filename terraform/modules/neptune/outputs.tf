# =============================================================================
# Neptune Module - Outputs
# =============================================================================

output "cluster_endpoint" {
  description = "Neptune cluster endpoint"
  value       = aws_neptune_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Neptune cluster reader endpoint"
  value       = aws_neptune_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "Neptune cluster port"
  value       = aws_neptune_cluster.main.port
}

output "cluster_arn" {
  description = "Neptune cluster ARN"
  value       = aws_neptune_cluster.main.arn
}

output "cluster_id" {
  description = "Neptune cluster ID"
  value       = aws_neptune_cluster.main.id
}

output "cluster_resource_id" {
  description = "Neptune cluster resource ID"
  value       = aws_neptune_cluster.main.cluster_resource_id
}
