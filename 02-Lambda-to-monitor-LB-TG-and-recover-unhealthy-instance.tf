resource "aws_iam_role" "lambda_reboot_instance_on_sns_alarm" {
  name               = "lambda_reboot_instance_on_sns_alarm-${var.tenant_id}-${var.infrastructure_purpose}"
  assume_role_policy = file("./iam/LambdaRole.json")
}

resource "aws_iam_role_policy" "lambda_reboot_instance_on_sns_alarm" {
  name   = "lambda_reboot_EC2instance_${var.tenant_id}_${var.infrastructure_purpose}"
  role   = aws_iam_role.lambda_reboot_instance_on_sns_alarm.id
  policy = data.aws_iam_policy_document.this_lambda.json

}



data "aws_iam_policy_document" "this_lambda" {
  statement {
    sid = "AllowDescribeAccessToLBAndTargetGroups"

    effect = "Allow"

    actions = [
      "elasticloadbalancing:Describe*"
    ]

    resources = [
      "*"
    ]
  }


  statement {
    sid = "AllowEc2InstanceReboot"

    effect = "Allow"

    actions = [
      "ec2:RebootInstances"
    ]

    resources = [
      "*"
    ]
  }


  statement {

    sid = "AllowLoggingToCloudwatch"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }


}


resource "aws_lambda_function" "lambda_reboot_instance_on_sns_alarm" {
  filename      = "./lambda_zip/RebootInstanceOnSNSAlarm.zip"
  function_name = "RebootInstanceOnSNSAlarm-${var.tenant_id}-${var.infrastructure_purpose}"
  role          = aws_iam_role.lambda_reboot_instance_on_sns_alarm.arn
  handler       = "RebootInstanceOnSNSAlarm::RebootInstanceOnSNSAlarm.Function::FunctionHandler"

  source_code_hash = filebase64sha256("./lambda_zip/RebootInstanceOnSNSAlarm.zip")
  runtime          = "dotnet6"
  publish          = true

  memory_size = 256
  timeout     = 20

}



resource "aws_sns_topic_subscription" "kurento_target_group_unhealthy_to_lambda" {
  topic_arn = aws_sns_topic.kurento_target_group_unhealthy.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_reboot_instance_on_sns_alarm.arn
}

resource "aws_lambda_permission" "allow_sns_to_call_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_reboot_instance_on_sns_alarm.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.kurento_target_group_unhealthy.arn
}



resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_reboot_instance_on_sns_alarm.function_name}"
  retention_in_days = 3
}