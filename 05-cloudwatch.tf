resource "aws_iam_instance_profile" "CloudWatch_Profile" {
  name = "Recording-CloudWatchProfile-${var.tenant_id}-${var.infrastructure_purpose}-${random_string.random_username.result}"
  role = aws_iam_role.CloudWatchAgentRole.name

}


resource "aws_iam_role_policy" "CloudWatchAgentPolicy" {
  name = "CloudWatchAgentPolicy-${var.tenant_id}-${var.infrastructure_purpose}-${random_string.random_username.result}"
  role = aws_iam_role.CloudWatchAgentRole.id

  policy = file("05-1-CloudWatchAgentServerPolicy.json")
}


resource "aws_iam_role" "CloudWatchAgentRole" {
  name = "Recording-${var.tenant_id}-${var.infrastructure_purpose}-${random_string.random_username.result}"

  assume_role_policy = file("05-2-CloudWatchAgentAssumePolicy.json")


  tags = {
    tag-key = "Recording-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}




resource "aws_cloudwatch_log_group" "kurento_log_group" {
  name              = "/kurento-${var.tenant_id}-${var.infrastructure_purpose}/"
  retention_in_days = 30

  
  tags = {
    Environment = var.infrastructure_purpose
    Application = "KurentoWorkers-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}



resource "aws_cloudwatch_log_stream" "kurento_log_streams" {
  count          = local.kurento_nodes
  name           = "logs-kurento-worker-${count.index+1}"
  log_group_name = aws_cloudwatch_log_group.kurento_log_group.name
}

resource "aws_cloudwatch_log_stream" "coturn_log_streams" {
  count          = local.use_turn_nodes ? local.turn_nodes : local.kurento_nodes 
  name           = "logs-coturn-for-kurento-worker-${count.index+1}"
  log_group_name = aws_cloudwatch_log_group.kurento_log_group.name
}

resource "aws_cloudwatch_log_group" "recsvc_log_group" {
  name              = "/recsvc-${var.tenant_id}-${var.infrastructure_purpose}/"
  retention_in_days = 30


  tags = {
    Environment = var.infrastructure_purpose
    Application = "ProcessingWorkers-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}

resource "aws_cloudwatch_log_group" "playsvc_log_group" {
  name              = "/playsvc-${var.tenant_id}-${var.infrastructure_purpose}/"
  retention_in_days = 30
  tags = {
    Environment = var.infrastructure_purpose
    Application = "PlayWorkers-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}

resource "aws_cloudwatch_log_stream" "recsvc_log_stream_processing_units" {
  count          = local.processing_nodes
  name           = "logs-processing-worker-${count.index+1}"
  log_group_name = aws_cloudwatch_log_group.recsvc_log_group.name
}

resource "aws_cloudwatch_log_stream" "playsvc_log_stream_processing_units" {
  count          = local.play_nodes
  name           = "logs-play-worker-${count.index+1}"
  log_group_name = aws_cloudwatch_log_group.playsvc_log_group.name
}

resource "aws_cloudwatch_log_stream" "recsvc_log_stream_archiver_units" {
  count          = local.processing_nodes
  name           = "logs-archiver-worker-${count.index+1}"
  log_group_name = aws_cloudwatch_log_group.recsvc_log_group.name
}



/******* Specify log metrics ********/

resource "aws_cloudwatch_log_metric_filter" "log_metric_filter_processing_unit" {
  name           = "processing-unit-error"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.recsvc_log_group.name



  metric_transformation {
    name      = "ProcessingUnitErrors"
    namespace = "ProcessingUnitFailures"
    value     = "1"
  }
}


resource "aws_cloudwatch_metric_alarm" "target-unhealthy-count" {
  alarm_name          = "Recoridng ${var.tenant_id} - Kurento Target Group health state changed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  dimensions = {
    LoadBalancer = aws_lb.recording_load_balancer.arn_suffix
    TargetGroup  = aws_lb_target_group.kurento_target_group.arn_suffix
  }

  alarm_description = "Shared Prod Recoridng alarm, triggered when Kurento target group reports 1 or more unhealthy hosts."
  actions_enabled   = "true"
  alarm_actions = [
    aws_sns_topic.kurento_target_group_unhealthy.arn
  ]
  ok_actions = [
    aws_sns_topic.kurento_target_group_healthy.arn
  ]
  treat_missing_data = "breaching"
}



resource "aws_sns_topic" "kurento_target_group_unhealthy" {
  name              = "shared_rec_kurento_target_group_has_unhealthy_host" 
}


resource "aws_sns_topic" "kurento_target_group_healthy" {
  name              = "shared_rec_kurento_target_group_all_hosts_healthy"  
}
