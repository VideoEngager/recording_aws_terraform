resource "aws_iam_instance_profile" "CloudWatch_Profile" {
  name = "Recording-CloudWatchProfile-${var.tenant_id}-${var.infrastructure_purpose}"
  role = aws_iam_role.CloudWatchAgentRole.name

}


resource "aws_iam_role_policy" "CloudWatchAgentPolicy" {
  name = "CloudWatchAgentPolicy-${var.tenant_id}-${var.infrastructure_purpose}"
  role = aws_iam_role.CloudWatchAgentRole.id

  policy = file("05-1-CloudWatchAgentServerPolicy.json")
}


resource "aws_iam_role" "CloudWatchAgentRole" {
  name = "Recording-${var.tenant_id}-${var.infrastructure_purpose}"

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



resource "aws_cloudwatch_log_stream" "kurento_log_stream_1" {
  name           = "logs-kurento-worker-1"
  log_group_name = aws_cloudwatch_log_group.kurento_log_group.name
}



resource "aws_cloudwatch_log_stream" "kurento_log_stream_2" {
  name           = "logs-kurento-worker-2"
  log_group_name = aws_cloudwatch_log_group.kurento_log_group.name
}



resource "aws_cloudwatch_log_stream" "coturn_log_stream_1" {
  name           = "logs-coturn-for-kurento-worker-1"
  log_group_name = aws_cloudwatch_log_group.kurento_log_group.name
}



resource "aws_cloudwatch_log_stream" "coturn_log_stream_2" {
  name           = "logs-coturn-for-kurento-worker-2"
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



resource "aws_cloudwatch_log_stream" "recsvc_log_stream_processing_unit_1" {
  name           = "logs-processing-worker-1"
  log_group_name = aws_cloudwatch_log_group.recsvc_log_group.name
}



resource "aws_cloudwatch_log_stream" "recsvc_log_stream_processing_unit_2" {
  name           = "logs-processing-worker-2"
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
  alarm_name          = "Shared Prod Recoridng - Kurento Target Group health state changed"
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
