#!/usr/bin/env python3
"""
Debug Huawei API to see what's wrong
"""
import os
import json
import requests

HUAWEI_APP_ID = "116046535"
HUAWEI_CLIENT_ID = "1850740994484473152"
HUAWEI_CLIENT_SECRET = "F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98"

BASE_URL = "https://connect-api.cloud.huawei.com"
AUTH_URL = f"{BASE_URL}/api/oauth2/v1/token"
PUBLISH_API = f"{BASE_URL}/api/publish/v2"

def get_access_token():
    """Get OAuth2 access token"""
    print("Getting token...")
    
    response = requests.post(
        AUTH_URL,
        json={
            'client_id': HUAWEI_CLIENT_ID,
            'client_secret': HUAWEI_CLIENT_SECRET,
            'grant_type': 'client_credentials'
        }
    )
    
    print(f"Token response status: {response.status_code}")
    data = response.json()
    print(f"Token response: {json.dumps(data, indent=2)}")
    
    return data.get('access_token')

def debug_upload_url(token):
    """Debug upload URL endpoint"""
    print("\n\nTrying different upload URL patterns...")
    
    headers = {
        'Authorization': f'Bearer {token}',
        'client_id': HUAWEI_CLIENT_ID,
    }
    
    # Try different resourceType values
    for resource_type in ['2', '1', '3', '0']:
        print(f"\n--- Trying resourceType={resource_type} ---")
        
        response = requests.get(
            f"{PUBLISH_API}/upload-url/for-obs",
            params={
                'appId': HUAWEI_APP_ID,
                'suffix': 'jpg',
                'resourceType': resource_type
            },
            headers=headers
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")

def main():
    token = get_access_token()
    
    if token:
        print(f"\n✓ Token obtained: {token[:50]}...")
        debug_upload_url(token)

if __name__ == "__main__":
    main()
