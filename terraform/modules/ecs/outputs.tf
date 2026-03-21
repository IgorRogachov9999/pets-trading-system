output "sg_alb_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "sg_ecs_id" {
  description = "Security group ID for ECS Fargate tasks."
  value       = aws_security_group.ecs.id
}

output "alb_dns_name" {
  description = "ALB DNS name — used as API Gateway VPC Link target."
  value       = aws_lb.trading_api.dns_name
}

output "alb_arn" {
  description = "ALB ARN — used when creating the API Gateway VPC Link."
  value       = aws_lb.trading_api.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used in CI/CD force-new-deployment commands."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name — used in CI/CD force-new-deployment commands."
  value       = aws_ecs_service.trading_api.name
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (runtime permissions)."
  value       = aws_iam_role.ecs_task.arn
}
