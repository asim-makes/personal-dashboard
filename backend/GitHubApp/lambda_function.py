import json
import requests
import os

def get_github_activity(username, headers):
    """
    Fetches and formats a user's recent GitHub activity.
    """
    try:
        response = requests.get(f"https://api.github.com/users/{username}/events/public", headers=headers)
        response.raise_for_status()
        events = response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GitHub events: {e}")
        return []

    activity_list = []
    for event in events:
        activity = {
            "id": event.get("id"),
            "type": event.get("type"),
            "repo": event.get("repo", {}).get("name"),
            "timestamp": event.get("created_at"),
            "message": "No message available"
        }

        if event["type"] == "PushEvent":
            activity["message"] = f"Pushed to {event['payload']['ref'].replace('refs/heads/', '')}"
            activity["commits"] = len(event["payload"]["commits"])
        elif event["type"] == "PullRequestEvent":
            pr_action = event["payload"]["action"]
            pr_title = event["payload"]["pull_request"]["title"]
            activity["message"] = f"Pull Request {pr_action}: {pr_title}"
        elif event["type"] == "CreateEvent":
            activity["message"] = f"Created a new {event['payload']['ref_type']}"
        elif event["type"] == "ForkEvent":
            activity["message"] = f"Forked {event['repo']['name']}"

        activity_list.append(activity)

    return activity_list

def get_profile_data(username, headers):
    """
    Fetches and formats a user's GitHub profile data.
    """
    try:
        response = requests.get(f"https://api.github.com/users/{username}", headers=headers)
        response.raise_for_status()
        profile = response.json()
        return {
            "name": profile.get("name"),
            "avatar_url": profile.get("avatar_url"),
            "followers": profile.get("followers"),
            "public_repos": profile.get("public_repos")
        }
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GitHub profile: {e}")
        return None

def get_repos_data(username, headers):
    """
    Fetches and formats a user's GitHub repositories.
    """
    try:
        response = requests.get(f"https://api.github.com/users/{username}/repos", headers=headers)
        response.raise_for_status()
        repos = response.json()
        
        repo_list = []
        for repo in repos:
            repo_list.append({
                "id": repo.get("id"),
                "name": repo.get("name"),
                "full_name": repo.get("full_name"),
                "description": repo.get("description"),
                "html_url": repo.get("html_url"),
                "language": repo.get("language"),
                "stargazers_count": repo.get("stargazers_count"),
                "forks_count": repo.get("forks_count"),
                "updated_at": repo.get("updated_at")
            })
        return repo_list
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GitHub repositories: {e}")
        return []

def handler(event, context):
    github_pat = os.environ.get('GITHUB_PAT')
    github_username = os.environ.get('GITHUB_USERNAME')

    # Handle CORS preflight (OPTIONS)
    if event.get("httpMethod") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "http://personal-dashboard-bucket.s3-website-us-east-1.amazonaws.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,Authorization"
            },
            "body": ""
        }

    if not github_pat:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "http://personal-dashboard-bucket.s3-website-us-east-1.amazonaws.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,Authorization"
            },
            "body": json.dumps({"error": "GitHub PAT not found in environment variables."})
        }

    headers = {
        "Authorization": f"token {github_pat}",
        "Accept": "application/vnd.github.v3+json"
    }

    try:
        profile_data = get_profile_data(github_username, headers)
        recent_activity = get_github_activity(github_username, headers)
        repos_data = get_repos_data(github_username, headers)

        dashboard_data = {
            "profile": profile_data,
            "recent_activity": recent_activity,
            "repositories": repos_data
        }

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "http://personal-dashboard-bucket.s3-website-us-east-1.amazonaws.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,Authorization"
            },
            "body": json.dumps(dashboard_data, indent=2)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "http://personal-dashboard-bucket.s3-website-us-east-1.amazonaws.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,Authorization"
            },
            "body": json.dumps({"error": str(e)})
        }

        # Change