#!/usr/bin/env python3
"""
Debug Huawei upload URL API response
"""
import requests

HUAWEI_APP_ID = "116046535"
HUAWEI_CLIENT_ID = "1850740994484473152"
HUAWEI_CLIENT_SECRET = "F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98"

BASE_URL = "https://connect-api.cloud.huawei.com"
AUTH_URL = f"{BASE_URL}/api/oauth2/v1/token"
PUBLISH_API = f"{BASE_URL}/api/publish/v2"

from pathlib import Path

SCREENSHOTS_DIR = Path(r"C:\Users\Bojan\gavra_android\store-assets\latest-screenshots")
screenshot = "Screenshot_20260127_050102_com.gbox.android.jp.jpg"
img_path = SCREENSHOTS_DIR / screenshot

def get_access_token():
    """Get OAuth2 access token"""
    response = requests.post(
        AUTH_URL,
        json={
            'client_id': HUAWEI_CLIENT_ID,
            'client_secret': HUAWEI_CLIENT_SECRET,
            'grant_type': 'client_credentials'
        }
    )
    data = response.json()
    return data.get('access_token')

token = get_access_token()
print(f"Token: {token[:50]}...\n")

file_size = img_path.stat().st_size
print(f"Uploading: {screenshot}")
print(f"File size: {file_size} bytes\n")

headers = {
    'Authorization': f'Bearer {token}',
    'client_id': HUAWEI_CLIENT_ID,
}

response = requests.get(
    f"{PUBLISH_API}/upload-url/for-obs",
    params={
        'appId': HUAWEI_APP_ID,
        'suffix': 'jpg',
        'fileName': screenshot,
        'contentLength': file_size,
        'resourceType': '3'
    },
    headers=headers,
    timeout=10
)

print(f"Status: {response.status_code}")
print(f"Response:\n{response.text}")

if response.status_code == 200:
    data = response.json()
    print(f"\nParsed JSON: {data}")
