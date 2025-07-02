output "sqs_queue_url" {
    value = aws_sqs_queue.order_submission_queue.id
}

output "api_gateway_url" {
    value = "https://${aws_api_gateway_rest_api.apigateway.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}/${aws_api_gateway_resource.ordersubmission.path_part}"

}