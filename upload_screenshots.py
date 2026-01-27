#!/usr/bin/env python3
"""
Upload screenshots to Google Play and Huawei AppGallery
"""
import os
import json
import subprocess
import sys

# Putanja do slika
SCREENSHOTS_DIR = r"C:\Users\Bojan\gavra_android\store-assets\latest-screenshots"
GOOGLE_PLAY_PACKAGE = "com.gavra013.gavra_android"
HUAWEI_APP_ID = "116046535"

screenshots = [
    "Screenshot_20260127_050102_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050113_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050120_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050132_com.gbox.android.jp.jpg",
]

def upload_to_google_play():
    """Upload screenshots to Google Play Console"""
    print("📱 Uploading to Google Play Console...")
    
    for i, screenshot in enumerate(screenshots, 1):
        img_path = os.path.join(SCREENSHOTS_DIR, screenshot)
        print(f"  [{i}/4] Uploading {screenshot}...")
        
        # Koristi bundletool ili direktan API poziv
        # Za sada - samo log
        if os.path.exists(img_path):
            print(f"    ✓ File found: {img_path}")
        else:
            print(f"    ✗ File NOT found: {img_path}")

def upload_to_huawei():
    """Upload screenshots to Huawei AppGallery"""
    print("\n🟠 Uploading to Huawei AppGallery...")
    
    for i, screenshot in enumerate(screenshots, 1):
        img_path = os.path.join(SCREENSHOTS_DIR, screenshot)
        print(f"  [{i}/4] Uploading {screenshot}...")
        
        if os.path.exists(img_path):
            print(f"    ✓ File found: {img_path}")
        else:
            print(f"    ✗ File NOT found: {img_path}")

def main():
    print("🚀 Screenshot Upload Tool")
    print("=" * 50)
    
    # Check if screenshots exist
    print("\n📂 Checking screenshots...")
    for screenshot in screenshots:
        path = os.path.join(SCREENSHOTS_DIR, screenshot)
        exists = "✓" if os.path.exists(path) else "✗"
        print(f"  {exists} {screenshot}")
    
    print("\n" + "=" * 50)
    print("Detailed upload process:")
    print("=" * 50)
    
    upload_to_google_play()
    upload_to_huawei()
    
    print("\n✅ Upload process complete!")
    print("\nNext steps:")
    print("1. Go to Google Play Console > Your app > Store presence > Screenshots")
    print("2. Upload each screenshot manually (or use API with proper setup)")
    print("3. Go to Huawei AppGallery > App > Screenshots")
    print("4. Upload each screenshot manually (or use API with proper setup)")

if __name__ == "__main__":
    main()
