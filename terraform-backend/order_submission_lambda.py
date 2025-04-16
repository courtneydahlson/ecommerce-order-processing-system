import boto3
import os
import json

# Initializing the SQS client using boto3
sqs = boto3.client("sqs")

# Retrieve the SQS queue URL from environment variables
QUEUE_URL = os.getenv("SQS_QUEUE_URL")

def lambda_handler(event, context):
    print('event')
    print(event)

    message_body = json.loads(event["body"])
    
    # Sending the parsed message to an SQS queue
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message_body)
        )

    return {
        'statusCode': 200,
        'headers': {
        'Access-Control-Allow-Origin': '*',  # Allow CORS from any domain
        'Access-Control-Allow-Methods': 'POST, OPTIONS',  # Allow POST and OPTIONS methods
        'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key',  # Allow certain headers
    },
        'body': json.dumps(response)  # Ensure body is a JSON string
    }
