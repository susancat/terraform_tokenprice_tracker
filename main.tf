provider "aws" {
  region = "ap-northeast-1"
}

variable "notification_email" {
  description = "Email address to receive SNS alerts"
  type        = string
}

# 建立 IAM Role 供 Lambda 使用
resource "aws_iam_role" "lambda_exec" {
  name = "tokenTracker-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 附加 DynamoDB 權限 Policy 給 Lambda Role
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda-dynamodb-token-policy"
  description = "Allow Lambda to write to TokenPriceHistory table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem"
      ]
      Resource = aws_dynamodb_table.token_price_history.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Lambda Function 本體
resource "aws_lambda_function" "token_tracker" {
  filename         = "token_tracker.zip"
  function_name    = "tokenTracker"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = filebase64sha256("token_tracker.zip")
  timeout          = 30

  environment {
    variables = {
      ENV = "prod"
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/tokenTracker"
  retention_in_days = 7
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily_token_tracker_schedule"
  schedule_expression = "cron(0 1 * * ? *)" # UTC 時間早上 1 點 = 台灣 9 點
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "lambda_token_tracker"
  arn       = aws_lambda_function.token_tracker.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_tracker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

resource "aws_sns_topic" "alert_topic" {
  name = "token_tracker_alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email # 🔁 替換成你的 Email
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "TokenTrackerLambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when token_tracker function has any error"
  dimensions = {
    FunctionName = aws_lambda_function.token_tracker.function_name
  }
  alarm_actions = [aws_sns_topic.alert_topic.arn]
}

resource "aws_dynamodb_table" "token_price_history" {
  name           = "TokenPriceHistory"
  billing_mode   = "PAY_PER_REQUEST"  # 無需設定 RCU/WCU，按量計費
  hash_key       = "symbol"
  range_key      = "timestamp"

  attribute {
    name = "symbol"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Project = "Token Tracker"
    ManagedBy = "Terraform"
  }
}
