# =============================================================================
# Neptune Module - Graph Database
# =============================================================================

# -----------------------------------------------------------------------------
# Neptune Subnet Group
# -----------------------------------------------------------------------------

resource "aws_neptune_subnet_group" "main" {
  name       = "${var.name_prefix}-neptune-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-neptune-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Neptune Parameter Group
# -----------------------------------------------------------------------------

resource "aws_neptune_cluster_parameter_group" "main" {
  name        = "${var.name_prefix}-neptune-params"
  family      = "neptune1.2"
  description = "Neptune cluster parameter group for ${var.name_prefix}"

  parameter {
    name  = "neptune_enable_audit_log"
    value = "1"
  }

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Neptune Cluster
# -----------------------------------------------------------------------------

resource "aws_neptune_cluster" "main" {
  cluster_identifier                   = "${var.name_prefix}-neptune"
  engine                               = "neptune"
  engine_version                       = var.engine_version
  port                                 = var.port
  backup_retention_period              = var.backup_retention_days
  preferred_backup_window              = var.preferred_backup_window
  vpc_security_group_ids               = [var.security_group_id]
  neptune_subnet_group_name            = aws_neptune_subnet_group.main.name
  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.main.name
  iam_database_authentication_enabled  = var.iam_authentication
  storage_encrypted                    = true
  kms_key_arn                          = var.kms_key_arn
  deletion_protection                  = var.deletion_protection
  skip_final_snapshot                  = var.deletion_protection ? false : true
  final_snapshot_identifier            = var.deletion_protection ? "${var.name_prefix}-neptune-final" : null

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-neptune"
  })
}

# -----------------------------------------------------------------------------
# Neptune Cluster Instances
# -----------------------------------------------------------------------------

resource "aws_neptune_cluster_instance" "main" {
  count = var.cluster_size

  identifier                   = "${var.name_prefix}-neptune-${count.index + 1}"
  cluster_identifier           = aws_neptune_cluster.main.id
  instance_class               = var.instance_class
  neptune_subnet_group_name    = aws_neptune_subnet_group.main.name
  publicly_accessible          = false
  auto_minor_version_upgrade   = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-neptune-${count.index + 1}"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.name_prefix}-neptune-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Neptune"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Neptune CPU utilization high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_neptune_cluster.main.id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${var.name_prefix}-neptune-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/Neptune"
  period              = 300
  statistic           = "Average"
  threshold           = 1000000000  # 1GB
  alarm_description   = "Neptune freeable memory low"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_neptune_cluster.main.id
  }

  tags = var.common_tags
}
