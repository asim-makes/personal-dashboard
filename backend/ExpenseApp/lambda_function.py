import json
import boto3
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('expenses-table')

def lambda_handler(event, context):
    http_method = event['httpMethod']

    if http_method == 'POST':
        return add_expense(event)
    elif http_method == 'GET':
        return get_expenses(event)
    elif http_method == 'DELETE':
        return delete_expense(event, context)
    else:
        return {
            'statusCode': 405,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE,PATCH'
            },
            'body': json.dumps({'message': 'Method Not Allowed'})
        }

def add_expense(event):
    try:
        # Check if 'body' exists and is not None
        if 'body' not in event or not event['body']:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Invalid request: Body is missing.'})
            }

        # Parse the body of the incoming request
        body = json.loads(event['body'])

        # --- Validation Check ---
        required_fields = ['description', 'amount', 'category', 'date']
        for field in required_fields:
            if field not in body:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                    },
                    'body': json.dumps({'message': f'Validation Error: Missing field "{field}".'})
                }

        # Validate data types
        if not isinstance(body['description'], str) or not body['description']:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Validation Error: "description" must be a non-empty string.'})
            }
        
        # This is the key check: ensure 'amount' is a number
        if not isinstance(body['amount'], (int, float, Decimal)):
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Validation Error: "amount" must be a number.'})
            }

        if not isinstance(body['category'], str):
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Validation Error: "category" must be a string.'})
            }
        
        if not isinstance(body['date'], str):
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Validation Error: "date" must be a string.'})
            }

        # --- End of Validation Check ---

        # Generate a Unix timestamp
        timestamp = int(datetime.utcnow().timestamp() * 1000)

        # Prepare the expense item for DynamoDB, converting amount to Decimal
        expense = {
            'expenseId': int(timestamp), # Using timestamp as a unique ID
            'description': body['description'],
            'timestamp': timestamp,
            'amount': Decimal(str(body['amount'])),
            'category': body['category'],
            'date': body['date']
        }
        
        # In a real-world scenario, you should get the table object from an external source or a global scope.
        table.put_item(Item=expense)

        return {
            'statusCode': 201,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': 'Expense added successfully!'})
        }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': 'Invalid JSON format.'})
        }
    except Exception as e:
        # Catch any other unexpected errors
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': 'Internal Server Error', 'error': str(e)})
        }

def get_expenses(event):
    try:
        # Check for query parameters and specifically the 'category' parameter
        query_params = event.get('queryStringParameters')
        
        if query_params and 'category' in query_params:
            category = query_params['category']
            # Use a Scan with a FilterExpression to filter by category
            response = table.scan(
                FilterExpression=boto3.dynamodb.conditions.Attr('category').eq(category)
            )
        else:
            # If no category parameter is provided, perform a simple full scan
            response = table.scan()

        # Convert Decimal to float or int for JSON serialization
        expenses = convert_decimal_to_float(response['Items'])
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE,PATCH'
            },
            'body': json.dumps({'expenses': expenses})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE,PATCH'
            },
            'body': json.dumps({'message': 'Error fetching expenses', 'error': str(e)})
        }

def delete_expense(event, context):
    try:
        # Extract the expenseId from the path parameter
        expense_id = event['pathParameters']['expenseId']
        
        try:
            expense_id = Decimal(expense_id)  # Convert to float if it's numeric (e.g., 123.0)
        except ValueError:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET, POST, DELETE'
                },
                'body': json.dumps({'message': 'Invalid expenseId. It must be a number.'})
            }

        delete_response = table.delete_item(
            Key={
                'expenseId': expense_id
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': f'Expense with ID {expense_id} deleted successfully!'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': 'Error deleting expense', 'error': str(e)})
        }

def update_expense(event):
    try:
        # Extract expenseId from the path parameter
        expense_id = event['pathParameters']['expenseId']

        # Parse the body of the incoming request
        body = json.loads(event['body'])

        # Prepare the updated values for DynamoDB
        update_expression = "SET"
        expression_attribute_values = {}

        # Dynamically build the update expression based on the provided fields
        if 'amount' in body:
            update_expression += " amount = :amount,"
            expression_attribute_values[':amount'] = Decimal(str(body['amount']))  # Convert to Decimal

        if 'description' in body:
            update_expression += " description = :description,"
            expression_attribute_values[':description'] = body['description']

        if 'category' in body:
            update_expression += " category = :category,"
            expression_attribute_values[':category'] = body['category']

        if 'date' in body:
            update_expression += " date = :date,"
            expression_attribute_values[':date'] = body['date']

        # Remove trailing comma
        update_expression = update_expression.rstrip(',')

        # Perform the update in DynamoDB
        response = table.update_item(
            Key={
                'expenseId': expense_id,
                'timestamp': 0  # Adjust if necessary
            },
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_attribute_values,
            ReturnValues="UPDATED_NEW"  # Returns the updated attributes
        )

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': f'Expense with ID {expense_id} updated successfully!'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET, POST, DELETE'
            },
            'body': json.dumps({'message': 'Error updating expense', 'error': str(e)})
        }


def get_expenses_by_category(event, context):
    try:
        # Extract the category from the path parameters
        if 'pathParameters' not in event or 'category' not in event['pathParameters']:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                },
                'body': json.dumps({'message': 'Category path parameter is missing.'})
            }
            
        category_name = event['pathParameters']['category']

        # Use the query operation which is more efficient for filtered data
        # 'category' needs to be a partition key (or a GSI partition key) on your DynamoDB table
        response = table.query(
            KeyConditionExpression=Key('category').eq(category_name)
        )
        
        expenses = response['Items']

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE,PATCH'
            },
            'body': json.dumps(expenses, cls=DecimalEncoder)
        }
    except Exception as e:
        print(f"Error fetching expenses: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,DELETE,PATCH'
            },
            'body': json.dumps({'message': 'Error fetching expenses', 'error': str(e)})
        }

# Helper function to convert DynamoDB Decimal objects to native Python types
def convert_decimal_to_float(items):
    if isinstance(items, list):
        return [convert_decimal_to_float(item) for item in items]
    elif isinstance(items, dict):
        return {key: convert_decimal_to_float(value) for key, value in items.items()}
    elif isinstance(items, Decimal):
        # Convert Decimal to float
        return float(items)
    else:
        return items
