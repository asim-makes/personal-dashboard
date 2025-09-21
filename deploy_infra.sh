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

  echo "Checking for IAM role: $role_name..."
  if aws iam get-role --role-name "$role_name" &> /dev/null; then
    echo "Role $role_name already exists. Skipping creation."
  else
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

# Create or update IAM roles
create_or_update_role "$BASIC_ROLE_NAME"
create_or_update_role "$EXPENSE_APP_ROLE_NAME" "$DYNAMODB_FULL_ACCESS_POLICY"

echo "Waiting for IAM roles to become available..."
sleep 5

declare -a APPS=("ExpenseApp")

for APP_NAME in "${APPS[@]}"; do
  echo "Processing $APP_NAME..."

  if [[ "$APP_NAME" == "ExpenseApp" ]]; then
      role_arn=$(aws iam get-role --role-name "$EXPENSE_APP_ROLE_NAME" --query "Role.Arn" --output text)
  else
      role_arn=$(aws iam get-role --role-name "$BASIC_ROLE_NAME" --query "Role.Arn" --output text)
  fi

  echo "Using Role ARN: $role_arn"

  rest_api_name="$APP_NAME"
  description="API for $APP_NAME"

  echo "Checking for existing REST API with name: $rest_api_name..."
  rest_api_id=$(aws apigateway get-rest-apis --query "items[?name=='$rest_api_name'].id" --output text --region $REGION_NAME)

  if [ -n "$rest_api_id" ]; then
    echo "Found existing REST API with ID: $rest_api_id"
  else
    echo "REST API not found. Creating a new one..."
    rest_api_id=$(aws apigateway create-rest-api \
      --name $rest_api_name \
      --description "$description" \
      --query 'id' --output text --region $REGION_NAME)
    echo "Created new REST API with ID: $rest_api_id"
  fi

  account_id=$(aws sts get-caller-identity --query 'Account' --output text)

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

  echo "Skipping automatic API Gateway → Lambda integrations."
  
  # Create deployment (empty methods, no integration)
  aws apigateway create-deployment \
    --rest-api-id "$rest_api_id" \
    --stage-name prod \
    --region $REGION_NAME

  endpoint_uri="https://${rest_api_id}.execute-api.$REGION_NAME.amazonaws.com/prod"
  echo "Endpoint URI for $APP_NAME: $endpoint_uri"

  echo "---"
done