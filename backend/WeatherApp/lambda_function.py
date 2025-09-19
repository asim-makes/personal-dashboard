import json
import os
import requests

def lambda_handler(event, context):
    """
    Lambda function to call the weatherapi.com API.
    """
    
    # It's best practice to get the API key from environment variables
    api_key = os.environ.get('WEATHER_API_KEY')
    if not api_key:
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps('WEATHERAPI_API_KEY not found in environment variables.')
        }

    body = event.get('body')

    if not body:
        return {
            'statusCode': 400,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps('Missing request body.')
        }

    try:
        # The body is a string, so you must parse it into a dictionary
        body_data = json.loads(body)
        location = body_data.get('location')
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps('Invalid JSON in the request body.')
        }
        
    if not location:
        return {
            'statusCode': 400,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps('Missing "location" key in the JSON body.')
        }

    # Construct the API URL
    url = f"http://api.weatherapi.com/v1/current.json?key={api_key}&q={location}"

    try:
        response = requests.get(url)
        response.raise_for_status()  # This will raise an HTTPError for bad responses (4xx or 5xx)
        weather_data = response.json()
        
        # Extract and return relevant information
        return {
            'statusCode': 200,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps({
                'location': weather_data['location']['name'],
                'country': weather_data['location']['country'],
                'temperature_c': weather_data['current']['temp_c'],
                'condition': weather_data['current']['condition']['text']
            })
        }
    
    except requests.exceptions.RequestException as e:
        print(f"Error calling WeatherAPI: {e}")
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps(f"Error retrieving weather data: {e}")
        }
    
    except json.JSONDecodeError:
        print("Invalid JSON response from API.")
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps("Error parsing API response.")
        }
    
    except KeyError:
        print("Unexpected API response format.")
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            },
            'body': json.dumps("Unexpected data format from API.")
        }