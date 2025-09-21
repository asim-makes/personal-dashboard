#!/bin/bash

# Define the region
REGION_NAME="us-east-1"

# Define the role and policy
BASIC_ROLE_NAME="LambdaDynamoDBCloudWatchRole"
BASIC_EXECUTION_POLICY="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
EXPENSE_APP_ROLE_NAME="LambdaDynamoDBRole"
DYNAMODB_FULL_ACCESS_POLICY="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

create_or_update_role() {
  local role_name=$1
  local policy_arn=$2

  # Check if the role already exists
  echo "Checking for IAM role: $role_name..."
  if aws iam get-role --role-name "$role_name" &> /dev/null; then
    echo "Role $role_name already exists. Skipping creation."
  else
    # Create a role with a trust relationship
    echo "Role not found. Creating $role_name..."
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }'
  fi

  # Attach the CloudWatch logging policy if it's not already attached
  echo "Checking for attached policy: $BASIC_EXECUTION_POLICY..."
  if ! aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='$BASIC_EXECUTION_POLICY']" --output text | grep -q "$BASIC_EXECUTION_POLICY"; then
    echo "Attaching policy: $BASIC_EXECUTION_POLICY..."
    aws iam attach-role-policy \
      --role-name "$role_name" \
      --policy-arn "$BASIC_EXECUTION_POLICY"
  else
    echo "Policy $BASIC_EXECUTION_POLICY is already attached. Skipping."
  fi

  if [[ -n "$policy_arn" ]]; then
      echo "Checking for attached policy: $policy_arn..."
      if ! aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='$policy_arn']" --output text | grep -q "$policy_arn"; then
        echo "Attaching policy: $policy_arn..."
        aws iam attach-role-policy \
          --role-name "$role_name" \
          --policy-arn "$policy_arn"
      else
        echo "Policy $policy_arn is already attached. Skipping."
      fi
  fi
}

enable_cors() {
  local rest_api_id=$1
  local resource_id=$2
  local method_name=$3

  echo "Enabling CORS for $method_name on resource $resource_id..."

  # Check if OPTIONS method already exists
  if ! aws apigateway get-method --rest-api-id "$rest_api_id" --resource-id "$resource_id" --http-method OPTIONS &> /dev/null; then
      echo "OPTIONS method not found. Creating it for preflight requests..."
      # Create OPTIONS method for preflight requests
      aws apigateway put-method \
        --rest-api-id "$rest_api_id" \
        --resource-id "$resource_id" \
        --http-method OPTIONS \
        --authorization-type NONE \
        --region $REGION_NAME

      aws apigateway put-integration \
        --rest-api-id "$rest_api_id" \
        --resource-id "$resource_id" \
        --http-method OPTIONS \
        --type MOCK \
        --passthrough-behavior WHEN_NO_MATCH \
        --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
        --region $REGION_NAME

      aws apigateway put-method-response \
        --rest-api-id "$rest_api_id" \
        --resource-id "$resource_id" \
        --http-method OPTIONS \
        --status-code 200 \
        --response-models '{"application/json": "Empty"}' \
        --response-parameters '{"method.response.header.Access-Control-Allow-Origin": true, "method.response.header.Access-Control-Allow-Headers": true, "method.response.header.Access-Control-Allow-Methods": true}' \
        --region $REGION_NAME

      aws apigateway put-integration-response \
        --rest-api-id "$rest_api_id" \
        --resource-id "$resource_id" \
        --http-method OPTIONS \
        --status-code 200 \
        --response-templates '{"application/json": ""}' \
        --response-parameters '{"method.response.header.Access-Control-Allow-Origin": "'\''*'\''", "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''"}' \
        --region $REGION_NAME
  else
      echo "OPTIONS method already exists. Skipping creation."
  fi
      
  aws apigateway put-method-response \
    --rest-api-id "$rest_api_id" \
    --resource-id "$resource_id" \
    --http-method "$method_name" \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin": true}' \
    --region $REGION_NAME
      
  aws apigateway put-integration-response \
    --rest-api-id "$rest_api_id" \
    --resource-id "$resource_id" \
    --http-method "$method_name" \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin": "'\''*'\''"}' \
    --region $REGION_NAME
}

create_method_and_integration() {
  local rest_api_id=$1
  local resource_id=$2
  local http_method=$3
  local lambda_uri=$4

  echo "Creating $http_method method for resource $resource_id..."

  # Get the AWS account ID
  account_id=$(aws sts get-caller-identity --query 'Account' --output text)

  # Define the lambda URI
  aws apigateway put-method \
    --rest-api-id "$rest_api_id" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --authorization-type NONE \
    --region $REGION_NAME

  aws apigateway put-integration \
    --rest-api-id "$rest_api_id" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --type AWS_PROXY \
    --integration-http-method "$http_method" \
    --uri "$lambda_uri" \
    --region "$REGION_NAME"
}
# Create or update IAM roles
create_or_update_role "$BASIC_ROLE_NAME"
create_or_update_role "$EXPENSE_APP_ROLE_NAME" "$DYNAMODB_FULL_ACCESS_POLICY"

echo "Waiting for IAM roles to become available..."
sleep 5


# declare -a APPS=("ExpenseApp", "GitHubApp", "NewsApp", "WeatherApp")
declare -a APPS=("ExpenseApp")


for APP_NAME in "${APPS[@]}"; do
  echo "Processing $APP_NAME..."

  # Determine the role ARN based on the app name
  if [[ "$APP_NAME" == "ExpenseApp" ]]; then
      role_arn=$(aws iam get-role --role-name "$EXPENSE_APP_ROLE_NAME" --query "Role.Arn" --output text)
  else
      role_arn=$(aws iam get-role --role-name "$BASIC_ROLE_NAME" --query "Role.Arn" --output text)
  fi

  echo "Using Role ARN: $role_arn"

  # Define the names for API Gateway
  rest_api_name="$APP_NAME"
  description="API for $APP_NAME"

  # Check if a REST API with the same name already exists
  echo "Checking for existing REST API with name: $rest_api_name..."
  rest_api_id=$(aws apigateway get-rest-apis --query "items[?name=='$rest_api_name'].id" --output text --region $REGION_NAME)

  if [ -n "$rest_api_id" ]; then
    echo "Found existing REST API with ID: $rest_api_id"
  else
    # Create a new REST API if one doesn't exist
    echo "REST API not found. Creating a new one..."
    rest_api_id=$(aws apigateway create-rest-api \
      --name $rest_api_name \
      --description "$description" \
      --query 'id' --output text --region $REGION_NAME)
    echo "Created new REST API with ID: $rest_api_id"
  fi

  # Get the AWS account ID
  account_id=$(aws sts get-caller-identity --query 'Account' --output text)

  # Create lambda function
  echo "Checking for Lambda function: ${APP_NAME}..."
  if aws lambda get-function --function-name "${APP_NAME}" &> /dev/null; then
    echo "Lambda function ${APP_NAME} already exists. Skipping creation."
  else
    LAMBDA_FILE="backend/${APP_NAME}/lambda_function.py"
    ZIP_FILE="${APP_NAME}.zip"

    if [ ! -f "$LAMBDA_FILE" ]; then
        echo "Error: $LAMBDA_FILE not found!"
        continue
    fi

    BUILD_DIR="build_${APP_NAME}"
    mkdir -p "$BUILD_DIR"

    cp "$LAMBDA_FILE" "$BUILD_DIR/lambda_function.py"

    if [ -f "backend/requirements.txt" ]; then
        echo "Installing dependencies for $APP_NAME..."
        pip install -r backend/requirements.txt -t "$BUILD_DIR"
    fi

    cd "$BUILD_DIR"
    zip -r ../"$ZIP_FILE" .
    cd ..

    rm -r "$BUILD_DIR"

    aws lambda create-function \
      --function-name "${APP_NAME}" \
      --runtime python3.11 \
      --zip-file "fileb://${ZIP_FILE}" \
      --handler "lambda_function.handler" \
      --role "$role_arn" \
      --timeout 30 \
      --memory-size 128 \
      --region $REGION_NAME

    echo "Successfully created Lambda function for $APP_NAME."
  fi
  
  PERMISSION_STATEMENT_ID="apigateway-invoke-permission"
    
  echo "Granting API Gateway permission to invoke Lambda..."

  # Check if a permission statement with the fixed ID already exists. If so, remove it.
  aws lambda remove-permission \
  --function-name "$APP_NAME" \
  --statement-id "$PERMISSION_STATEMENT_ID" \
  --region "$REGION_NAME" 2> /dev/null || true

  # Add the new, correct permission statement using the fixed ID
  # aws lambda add-permission \
  #   --function-name "$APP_NAME" \
  #   --statement-id "$PERMISSION_STATEMENT_ID" \
  #   --action "lambda:InvokeFunction" \
  #   --principal "apigateway.amazonaws.com" \
  #   --source-arn "arn:aws:execute-api:$REGION_NAME:$account_id:$rest_api_id/*/*/$APP_NAME" \
  #   --region "$REGION_NAME"

  # aws lambda add-permission \
  #   --function-name ExpenseApp \
  #   --statement-id apigateway-get-root \
  #   --action "lambda:InvokeFunction" \
  #   --principal apigateway.amazonaws.com \
  #   --source-arn "arn:aws:execute-api:$REGION_NAME:$account_id:$rest_api_id/prod/GET/*" \
  #   --region $REGION_NAME

  # aws lambda add-permission \
  #   --function-name ExpenseApp \
  #   --statement-id apigateway-post-root \
  #   --action "lambda:InvokeFunction" \
  #   --principal apigateway.amazonaws.com \
  #   --source-arn "arn:aws:execute-api:$REGION_NAME:$account_id:$rest_api_id/prod/POST/*" \
  #   --region $REGION_NAME

  # aws lambda add-permission \
  #   --function-name ExpenseApp \
  #   --statement-id apigateway-delete-expenseid \
  #   --action "lambda:InvokeFunction" \
  #   --principal apigateway.amazonaws.com \
  #   --source-arn "arn:aws:execute-api:$REGION_NAME:$account_id:$rest_api_id/prod/DELETE/*" \
  #   --region $REGION_NAME

  
  echo "Successfully granted API Gateway permission to invoke Lambda."
  sleep 5

  root_resource_id=$(aws apigateway get-resources \
    --rest-api-id "$rest_api_id" \
    --query 'items[?path==`/`].id' --output text --region $REGION_NAME)
  echo "Root Resource ID: $root_resource_id"

  # Define the lambda URI
  lambda_uri="arn:aws:apigateway:$REGION_NAME:lambda:path/2015-03-21/functions/arn:aws:lambda:$REGION_NAME:$account_id:function:$APP_NAME/invocations"

  # Configure method and its integration
  create_method_and_integration "$rest_api_id" "$root_resource_id" "GET" "$lambda_uri"
  enable_cors "$rest_api_id" "$root_resource_id" "GET"
  
  # Add conditional resources and methods for ExpenseApp
  if [[ "$APP_NAME" == "ExpenseApp" ]]; then
    echo "Configuring specific methods for ExpenseApp..."

    # Create a POST method on the root resource
    create_method_and_integration "$rest_api_id" "$root_resource_id" "POST" "$lambda_uri"
    enable_cors "$rest_api_id" "$root_resource_id" "POST"

    # Create a /{expenseid} resource for DELETE
    expenseid_resource_id=$(aws apigateway create-resource \
      --rest-api-id "$rest_api_id" \
      --parent-id "$root_resource_id" \
      --path-part "{expenseid}" \
      --query 'id' --output text --region $REGION_NAME)
    echo "Created /{expenseid} resource with ID: $expenseid_resource_id"
    
    create_method_and_integration "$rest_api_id" "$expenseid_resource_id" "DELETE" "$lambda_uri"
    enable_cors "$rest_api_id" "$expenseid_resource_id" "DELETE"
  fi

  # Create deployment
  # aws apigateway create-deployment \
  #   --rest-api-id "$rest_api_id"\
  #   --stage-name prod \
  #   --region $REGION_NAME
  
  endpoint_uri="https://${rest_api_id}.execute-api.$REGION_NAME.amazonaws.com/prod"

  # Retrieve the URI
  echo "Endpoint URI for $APP_NAME: $endpoint_uri"
  
  echo "---"
done