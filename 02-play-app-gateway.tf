resource "aws_apigatewayv2_api" "play_gateway" {
  count         = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  name          = "PlayGW-${var.tenant_id}-${var.infrastructure_purpose}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["content-type, authorization, content-length, x-requested-with"]
    allow_methods = ["GET","POST","PUT","DELETE","OPTIONS"]
    allow_origins = ["*"]
  }
  tags = {
    Name        = "PlayAppGateway-${var.tenant_id}"
    Environment = var.infrastructure_purpose
  }
}

resource "aws_apigatewayv2_integration" "play_gateway_integration" {
  count               = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  api_id              = aws_apigatewayv2_api.play_gateway[0].id
  integration_type    = "HTTP_PROXY"
  integration_method  = "ANY"
  integration_uri     = "http://${aws_lb.play_load_balancer[0].dns_name}:${var.play_listener_port}/{proxy}" 
}

resource "aws_apigatewayv2_route" "play_gateway_route" {
  count               = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  api_id              = aws_apigatewayv2_api.play_gateway[0].id
  route_key           = "ANY /{proxy+}"
  target              = "integrations/${aws_apigatewayv2_integration.play_gateway_integration[0].id}"
}

resource "aws_apigatewayv2_stage" "play_gateway_stage" {
  count               = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  api_id              = aws_apigatewayv2_api.play_gateway[0].id
  name                = "$default"
  auto_deploy = true

  tags = {
    Name        = "PlayAppGatewayStage-${var.tenant_id}"
    Environment = var.infrastructure_purpose
  }  
}