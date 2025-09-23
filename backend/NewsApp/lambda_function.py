import os
import json
import requests

# This function is the entry point for your AWS Lambda function.
# It fetches the latest news from the News API and formats the
# data to be consumed by your frontend application.
def handler(event, context):
    """
    Handles the Lambda invocation to fetch and format news articles.

    Args:
        event: The event object passed by the Lambda service.
        context: The context object passed by the Lambda service.

    Returns:
        A dictionary representing the HTTP response with news articles or an error.
    """
    try:
        # Get the API key from environment variables for security
        api_key = os.environ.get("NEWS_API_KEY")
        if not api_key:
            raise ValueError("NEWS_API_KEY environment variable is not set.")

        # Define the API endpoint and parameters.
        # Here we are fetching top headlines for 'us' in the 'technology' category.
        # You can customize these parameters based on your needs.
        url = "https://newsapi.org/v2/top-headlines"
        params = {
            "country": "us",
            "category": "technology",
            "apiKey": api_key
        }
        
        # Make the API request to News API
        response = requests.get(url, params=params)
        response.raise_for_status()  # This will raise an HTTPError for bad responses (4xx or 5xx)
        
        data = response.json()
        articles = data.get("articles", [])
        
        # Format the articles to match the frontend's NewsArticle type
        # We need to map fields and generate a unique ID.
        formatted_articles = []
        for i, article in enumerate(articles):
            formatted_articles.append({
                "id": i + 1,
                "title": article.get("title"),
                # News API uses 'description' for the summary
                "summary": article.get("description"),
                "source": article.get("source", {}).get("name"),
                "publishedAt": article.get("publishedAt"),
                "url": article.get("url")
            })

        # Return a successful response with the formatted data
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                # Add CORS headers if your frontend is on a different domain
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({
                "articles": formatted_articles
            })
        }

    except ValueError as e:
        # Handle cases where the API key is missing
        print(f"Configuration error: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"error": "Configuration error: " + str(e)})
        }
        
    except requests.exceptions.RequestException as e:
        # Handle cases where the API request fails (e.g., network error, bad status code)
        print(f"API request failed: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"error": "Failed to fetch news data from external API."})
        }
        
    except Exception as e:
        # Handle any other unexpected errors
        print(f"An unexpected error occurred: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"error": "An unexpected server error occurred."})
        }
