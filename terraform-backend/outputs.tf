output "sqs_queue_url" {
    value = aws_sqs_queue.order_submission_queue.id
}