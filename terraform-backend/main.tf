# API Gateway REST API
resource "aws_api_gateway_rest_api" "apigateway" {
  name        = "ordersubmissionTF"
  description = "API Gateway trigger Order Submission Lambda"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


resource "aws_api_gateway_resource" "ordersubmission" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  parent_id   = aws_api_gateway_rest_api.apigateway.root_resource_id
  path_part   = "ordersubmission"
}

resource "aws_api_gateway_method" "post_ordersubmission" {
  rest_api_id   = aws_api_gateway_rest_api.apigateway.id
  resource_id   = aws_api_gateway_resource.ordersubmission.id
  http_method   = "POST"
  authorization = "NONE"
}


resource "aws_api_gateway_method_response" "post_method_response" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  resource_id = aws_api_gateway_resource.ordersubmission.id
  http_method = aws_api_gateway_method.post_ordersubmission.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# resource "aws_api_gateway_integration_response" "post_integration_response" {
#   rest_api_id = aws_api_gateway_rest_api.apigateway.id
#   resource_id = aws_api_gateway_resource.ordersubmission.id
#   http_method = aws_api_gateway_method.post_ordersubmission.http_method
#   status_code = aws_api_gateway_method_response.post_method_response.status_code

#   response_templates = {
#     "application/json" = ""
#   }

#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = "'*'"
#     "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
#   }
# }

resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.apigateway.id
  resource_id   = aws_api_gateway_resource.ordersubmission.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# MOCK integration for OPTIONS method
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  resource_id = aws_api_gateway_resource.ordersubmission.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  integration_http_method = "OPTIONS"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS method response (CORS headers)
resource "aws_api_gateway_method_response" "options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  resource_id = aws_api_gateway_resource.ordersubmission.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Integration response for OPTIONS method (CORS headers)
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  resource_id = aws_api_gateway_resource.ordersubmission.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  depends_on = [
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_method_response.options_method_response
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
  }
}

# IAM Role for Order Submission Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "order_submission_lambda_tf_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Lambda Order Submission Function

resource "aws_lambda_function" "order_submission" {
  function_name = "OrderSubmissionLambda-TF"
  handler       = "order_submission_lambda.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "order_submission_lambda.zip"
  source_code_hash = filebase64sha256("order_submission_lambda.zip")

  environment {
    variables = {
        SQS_QUEUE_URL = aws_sqs_queue.order_submission_queue.id
    }
  }
}

# Integration (API Gateway -> Lambda)
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id
  resource_id = aws_api_gateway_resource.ordersubmission.id
  http_method = aws_api_gateway_method.post_ordersubmission.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_submission.invoke_arn
}

# Lambda permission to be invoked by API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_submission.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.apigateway.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.apigateway.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_rest_api.apigateway.id,
      aws_api_gateway_method.post_ordersubmission.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_resource.ordersubmission.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.post_ordersubmission,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_resource.ordersubmission,
    aws_api_gateway_integration_response.options_integration_response
  ]
}

# Stage
resource "aws_api_gateway_stage" "stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.apigateway.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

#Create SQS Queue with redrive policy
resource "aws_sqs_queue" "order_submission_queue" {
  name = "order-submission-queue-tf"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_submission_dlq.arn
    maxReceiveCount     = 5  # move to DLQ after 5 failed receives
  })
}

#Create DLQ
resource "aws_sqs_queue" "order_submission_dlq" {
  name = "order-submission-dlq-tf"
}

#IAM role policy for order submission Lambda to send SQS message
resource "aws_iam_role_policy" "order_submission_lambda_sqs_policy" {
  name = "LambdaSQSSendPolicyTF"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:SendMessage"
        ],
        Effect   = "Allow",
        Resource = aws_sqs_queue.order_submission_queue.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}


#order processing Lambda
resource "aws_lambda_function" "order_processing_lambda" {
  function_name = "OrderProcessingLambda-TF"
  handler       = "order_processing_lambda.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.order_processing_lambda_role.arn
  filename      = "order_processing_lambda.zip"
  source_code_hash = filebase64sha256("order_processing_lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.order_processing_table.id
    }
  }
}


# IAM Role for Order Processing Lambda
resource "aws_iam_role" "order_processing_lambda_role" {
  name = "order_processing_lambda_tf_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Execution policy
resource "aws_iam_role_policy_attachment" "order_processing_logs" {
  role       = aws_iam_role.order_processing_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for SQS
resource "aws_iam_role_policy" "order_processing_sqs_policy" {
  name = "OrderProcessingSQSPolicyTF"
  role = aws_iam_role.order_processing_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.order_submission_queue.arn
      }
    ]
  })
}
#When message is in order submission queue invoke lambda order processing
resource "aws_lambda_event_source_mapping" "sqs_to_processing_lambda" {
  event_source_arn = aws_sqs_queue.order_submission_queue.arn
  function_name    = aws_lambda_function.order_processing_lambda.arn
  batch_size       = 1
  enabled          = true
}

#Gives permissions for sqs to invoke lambda
resource "aws_lambda_permission" "allow_sqs_invoke" {
  statement_id  = "AllowSQSToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processing_lambda.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.order_submission_queue.arn
}

# DynamoDB table

resource "aws_dynamodb_table" "order_processing_table" {
  name         = "order_processing_table_tf"
  billing_mode = "PROVISIONED"
  read_capacity = 5
  write_capacity = 5
  hash_key     = "customer_id"

  attribute {
    name = "customer_id"
    type = "N"
  }

  tags = {
    Name = "OrderProcessingTable"
  }
}

#IAM Policy allowing order processing lambda to write to dynamodb

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "LambdaWriteDynamoPolicyTF"
  role = aws_iam_role.order_processing_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.order_processing_table.arn
      }
    ]
  })
}

# Cloudwatch Alarm on DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "DLQHasMessagesTF"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggers when DLQ has messages."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.sns_dlq_notification.arn]

  dimensions = {
    QueueName = aws_sqs_queue.order_submission_dlq.name
  }
}

#Create SNS Topic and Subscription
resource "aws_sns_topic" "sns_dlq_notification" {
  name = "sns_dlq_notification_tf"
}

resource "aws_sns_topic_subscription" "sns_email_notification" {
  topic_arn = aws_sns_topic.sns_dlq_notification.arn
  protocol  = "email"
  endpoint  = var.notification_email 
}
