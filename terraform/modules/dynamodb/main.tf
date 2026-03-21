# ==============================================================================
# modules/dynamodb/main.tf
# DynamoDB table for WebSocket connection tracking (traderId → connectionId).
# TTL enables automatic cleanup of stale connections without a background job.
# Architecture reference: docs/architecture/07-deployment-view.md
# ==============================================================================

resource "aws_dynamodb_table" "connections" {
  name         = "${var.project_name}-${var.environment}-websocket-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "traderId"

  attribute {
    name = "traderId"
    type = "S"
  }

  attribute {
    name = "connectionId"
    type = "S"
  }

  # GSI on connectionId so Trading API can look up traderId when a WS disconnects
  global_secondary_index {
    name            = "connectionId-index"
    hash_key        = "connectionId"
    projection_type = "ALL"
  }

  # TTL auto-removes expired connection records
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-dynamodb-connections"
  }
}
