output "rest_api_id" {
  description = "REST API Gateway ID."
  value       = aws_api_gateway_rest_api.main.id
}

output "rest_api_url" {
  description = "REST API invoke URL (stage endpoint)."
  value       = aws_api_gateway_stage.main.invoke_url
}

output "websocket_api_id" {
  description = "WebSocket API Gateway ID."
  value       = aws_apigatewayv2_api.websocket.id
}

output "websocket_api_endpoint" {
  description = "WebSocket API endpoint URL — used by the React SPA and Trading API."
  value       = aws_apigatewayv2_stage.websocket.invoke_url
}
