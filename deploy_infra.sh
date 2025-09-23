#!/bin/bash

source ./secrets

# Define the region
REGION_NAME="us-east-1"

# Define the role and policy
BASIC_ROLE_NAME="LambdaDynamoDBCloudWatchRole"
BASIC_EXECUTION_POLICY="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
EXPENSE_APP_ROLE_NAME="LambdaDynamoDBRole"
DYNAMODB_FULL_ACCESS_POLICY="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

create_or_update_role()
{
    local role_name=$1
    local policy_arn=$2

    echo "Checking for IAM role: $role_name..."
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
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

    # Attach CloudWatch logging policy
    echo "Checking for attached policy: $BASIC_EXECUTION_POLICY..."
    if ! aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='$BASIC_EXECUTION_POLICY']" --output text | grep -q "$BASIC_EXECUTION_POLICY"; then
        echo "Attaching policy: $BASIC_EXECUTION_POLICY..."
        aws iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "$BASIC_EXECUTION_POLICY"
    else
        echo "Policy $BASIC_EXECUTION_POLICY is already attached. Skipping."
    fi

    # Attach DynamoDB policy only for ExpenseApp
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

enable_cors()
{
    local rest_api_id=$1
    local resource_id=$2
    local method_name=$3

    echo "Enabling CORS for $method_name on resource $resource_id..."

    # Create OPTIONS method for preflight requests
    if ! aws apigateway get-method --rest-api-id "$rest_api_id" --resource-id "$resource_id" --http-method OPTIONS &>/dev/null; then
        echo "OPTIONS method not found. Creating it for preflight requests..."

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

create_method_and_integration()
{
    local rest_api_id=$1
    local resource_id=$2
    local http_method=$3
    local lambda_uri=$4

    echo "Creating $http_method method for resource $resource_id..."

    account_id=$(aws sts get-caller-identity --query 'Account' --output text)

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
        --integration-http-method POST \
        --uri "$lambda_uri" \
        --region "$REGION_NAME"
}

create_or_update_role "$BASIC_ROLE_NAME"
create_or_update_role "$EXPENSE_APP_ROLE_NAME" "$DYNAMODB_FULL_ACCESS_POLICY"

echo "Waiting for IAM roles to become available..."
sleep 5

declare -a APPS=("ExpenseApp", "GitHubApp", "NewsApp", "WeatherApp")

for APP_NAME in "${APPS[@]}"; do
    echo "Processing $APP_NAME..."

    if [[ "$APP_NAME" == "ExpenseApp" ]]; then
        role_arn=$(aws iam get-role --role-name "$EXPENSE_APP_ROLE_NAME" --query "Role.Arn" --output text)
    else
        role_arn=$(aws iam get-role --role-name "$BASIC_ROLE_NAME" --query "Role.Arn" --output text)
    fi

    echo "Using Role ARN: $role_arn"

    # Define the names for API Gateway
    rest_api_name="$APP_NAME"
    description="API for $APP_NAME"

    echo "Checking for existing REST API with name: $rest_api_name..."
    rest_api_id=$(aws apigateway get-rest-apis --query "items[?name=='$rest_api_name'].id" --output text --region $REGION_NAME)

    # Create REST API
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

    # Create lambda function
    echo "Checking for Lambda function: ${APP_NAME}..."
    if aws lambda get-function --function-name "${APP_NAME}" &>/dev/null; then
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

        ENV_VARS=""

        if [[ "$APP_NAME" == "NewsApp" ]]; then
          ENV_VARS="--environment Variables={NEWS_API_KEY=${NEWS_API_KEY}}"
        elif [[ "$APP_NAME" == "WeatherApp" ]]; then
          ENV_VARS="--environment Variables={WEATHER_API_KEY=${WEATHER_API_KEY}}"
        elif [[ "$APP_NAME" == "GitHubApp" ]]; then
          ENV_VARS="--environment Variables={GITHUB_PAT=${GITHUB_PAT},GITHUB_USERNAME=${GITHUB_USERNAME}}"
        fi

        aws --no-cli-pager lambda create-function \
            --function-name "${APP_NAME}" \
            --runtime python3.11 \
            --zip-file "fileb://${ZIP_FILE}" \
            --handler "lambda_function.handler" \
            --role "$role_arn" \
            --timeout 30 \
            --memory-size 128 \
            --region $REGION_NAME \
            $ENV_VARS

        echo "Successfully created Lambda function for $APP_NAME."
        echo "Cleaning up unnecessary files..."
        rm -rf *.zip
        echo "Clean successful"
    fi

    echo "Granting API Gateway permission to invoke Lambda..."

    # Remove existing permissions to avoid conflicts
    aws lambda remove-permission \
        --function-name "$APP_NAME" \
        --statement-id "apigateway-invoke-permission" \
        --region "$REGION_NAME" 2>/dev/null || true

    # Add permissions for all methods on all resources
    aws lambda add-permission \
        --function-name "$APP_NAME" \
        --statement-id "apigateway-invoke-permission" \
        --action "lambda:InvokeFunction" \
        --principal "apigateway.amazonaws.com" \
        --source-arn "arn:aws:execute-api:$REGION_NAME:$account_id:$rest_api_id/*/*" \
        --region "$REGION_NAME"

    echo "Successfully granted API Gateway permission to invoke Lambda."
    sleep 5

    root_resource_id=$(aws apigateway get-resources \
        --rest-api-id "$rest_api_id" \
        --query 'items[?path==`/`].id' --output text --region $REGION_NAME)
    echo "Root Resource ID: $root_resource_id"

    # Create a resource under root resource: /${APP_NAME}
    echo "Creating /$APP_NAME resource..."
    app_resource_id=$(aws apigateway create-resource \
        --rest-api-id "$rest_api_id" \
        --parent-id "$root_resource_id" \
        --path-part "$APP_NAME" \
        --query 'id' --output text --region $REGION_NAME 2>/dev/null \
        || aws apigateway get-resources \
            --rest-api-id "$rest_api_id" \
            --query "items[?pathPart=='$APP_NAME'].id" --output text --region $REGION_NAME)

    echo "ExpenseApp Resource ID: $app_resource_id"

    lambda_uri="arn:aws:apigateway:$REGION_NAME:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION_NAME:$account_id:function:$APP_NAME/invocations"

    # Add CORS to root resource (/)
    echo "Adding CORS to root resource (/) for $APP_NAME..."
    enable_cors "$rest_api_id" "$root_resource_id" "GET"

    # Add a query parameter on GET for ExpenseApp. Else, create the method normally.
    if [[ "$APP_NAME" == "ExpenseApp" ]]; then
        echo "Configuring GET method with query parametes for ExpenseApp"

        aws apigateway put-method \
            --rest-api-id "$rest_api_id" \
            --resource-id "$app_resource_id" \
            --http-method "GET" \
            --authorization-type NONE \
            --request-parameters '{"method.request.querystring.category": false}' \
            --region $REGION_NAME

        aws apigateway put-integration \
            --rest-api-id "$rest_api_id" \
            --resource-id "$app_resource_id" \
            --http-method "GET" \
            --type AWS_PROXY \
            --integration-http-method POST \
            --uri "$lambda_uri" \
            --region $REGION_NAME
    else
        create_method_and_integration "$rest_api_id" "$app_resource_id" "GET" "$lambda_uri"
    fi
    enable_cors "$rest_api_id" "$app_resource_id" "GET"

    # Additional resources and methods for ExpenseApp
    if [[ "$APP_NAME" == "ExpenseApp" ]]; then
        echo "Configuring specific methods for ExpenseApp..."

        # Method 1: POST
        create_method_and_integration "$rest_api_id" "$app_resource_id" "POST" "$lambda_uri"
        enable_cors "$rest_api_id" "$app_resource_id" "POST"

        # Method 2: DELETE for /{expenseId} resource under /ExpenseApp
        expenseid_resource_id=$(aws apigateway create-resource \
            --rest-api-id "$rest_api_id" \
            --parent-id "$app_resource_id" \
            --path-part "{expenseId}" \
            --query 'id' --output text --region $REGION_NAME 2>/dev/null \
            || aws apigateway get-resources \
                --rest-api-id "$rest_api_id" \
                --query "items[?pathPart=='{expenseId}' && parentId=='$app_resource_id'].id" --output text --region $REGION_NAME)

        echo "Created /ExpenseApp/{expenseId} resource with ID: $expenseid_resource_id"

        create_method_and_integration "$rest_api_id" "$expenseid_resource_id" "DELETE" "$lambda_uri"
        enable_cors "$rest_api_id" "$expenseid_resource_id" "DELETE"
    fi

    # Deploy the trigger
    aws apigateway create-deployment \
        --rest-api-id "$rest_api_id" \
        --stage-name prod \
        --region $REGION_NAME

    endpoint_uri="https://${rest_api_id}.execute-api.$REGION_NAME.amazonaws.com/prod/${APP_NAME}"

    echo "Endpoint URI for $APP_NAME: $endpoint_uri"

    echo "---"
done