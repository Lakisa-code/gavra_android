#!/usr/bin/env python3
"""
Fix Google Play listing and commit screenshots
"""
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build

GOOGLE_PLAY_PACKAGE = "com.gavra013.gavra_android"
GOOGLE_SERVICE_KEY = r"C:\Users\Bojan\gavra_android\AI BACKUP\secrets\google\play-store-key.json"

def fix_google_play_listing():
    """Add title and description to fix commit error"""
    print("🔧 Fixing Google Play listing...")
    
    try:
        # Load credentials
        credentials = service_account.Credentials.from_service_account_file(
            GOOGLE_SERVICE_KEY,
            scopes=["https://www.googleapis.com/auth/androidpublisher"]
        )
        
        service = build('androidpublisher', 'v3', credentials=credentials)
        
        # Create new edit
        edit_request = service.edits().insert(
            body={},
            packageName=GOOGLE_PLAY_PACKAGE
        )
        edit_result = edit_request.execute()
        edit_id = edit_result['id']
        
        print(f"✓ Created edit: {edit_id}")
        
        # Update listing with title
        listing_request = service.edits().listings().update(
            packageName=GOOGLE_PLAY_PACKAGE,
            editId=edit_id,
            language='en-US',
            body={
                'title': 'Gavra 013',
                'shortDescription': 'Travel organization and trip planning app',
                'fullDescription': 'Gavra 013 is a comprehensive travel and trip organization application designed to help users plan, organize, and manage their journeys effectively. Features include trip planning, location sharing, travel notes, and more.'
            }
        )
        listing_result = listing_request.execute()
        
        print(f"✓ Updated listing with title")
        
        # Now commit
        commit_request = service.edits().commit(
            packageName=GOOGLE_PLAY_PACKAGE,
            editId=edit_id
        )
        commit_result = commit_request.execute()
        
        print(f"✅ Successfully committed! Edit ID: {commit_result['id']}")
        return True
        
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

if __name__ == "__main__":
    fix_google_play_listing()
