import json
import boto3
import os
import uuid

# Creating a DynamoDB instance 
dynamodb = boto3.resource('dynamodb')
table_name = os.getenv("TABLE_NAME")
table = dynamodb.Table(table_name)


def lambda_handler(event, context):
    print('event')
    print(event)
    # Parsing the incoming event from sqs
    order_data = json.loads(event["Records"][0]["body"])

    # Extracting specific details from the 'order_data' dictionary
    customer_id = int(order_data['customer_id'])
    product_id = order_data['product_id']
    quantity = order_data['quantity']
    order_date = order_data['order_date']
    order_id = str(uuid.uuid4())

    # Inserting the extracted order data into the DynamoDB table
    response = table.put_item(
        Item = {
            'customer_id': customer_id,
            'order_id': order_id,
            'product_id': product_id,
            'quantity': quantity,
            'order_date': order_date
        }
        )

    return 
    {'statusCode': 200,
    'body': json.dumps('Order successfully saved to DynamoDB'),
    'response': response   
    }