# 🔐 Setup GitHub Secrets for Automatic Building

## Step 1: Encode your keystore file

```powershell
# In your project directory, run:
$keystoreBytes = [System.IO.File]::ReadAllBytes("android\gavra-release-key-production.keystore")
$keystoreBase64 = [System.Convert]::ToBase64String($keystoreBytes)
$keystoreBase64 | Out-File -FilePath "keystore-base64.txt" -Encoding ASCII
Write-Host "Keystore encoded! Check keystore-base64.txt file"
```

## Step 2: Add GitHub Secrets

Go to your GitHub repository:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

### Required Secrets:
- **Name:** `KEYSTORE_BASE64`
- **Value:** Contents of `keystore-base64.txt` file (the long base64 string)

### Optional Secrets (for enhanced security):
- **Name:** `KEYSTORE_PASSWORD` 
- **Value:** `GavraRelease2024`
- **Name:** `KEY_ALIAS`
- **Value:** `gavra-release-key`

## Step 3: Trigger Build

### Automatic Triggers:
- Push to `main` branch
- Create Pull Request to `main`

### Manual Trigger:
1. Go to **Actions** tab in GitHub
2. Select **🚀 Build Android Release**
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Step 4: Download Results

After successful build:
1. Go to **Actions** tab
2. Click on your workflow run
3. Scroll down to **Artifacts**
4. Download `gavra-android-release`
5. Extract to find your `.aab` file for Play Store!

## 🎯 What the workflow does:
✅ Checks out your code  
✅ Sets up Flutter & Java  
✅ Installs dependencies  
✅ Runs code analysis  
✅ Builds signed release (.aab) OR debug (.apk)  
✅ Uploads artifacts for download  

## 🚨 Security Notes:
- Keystore is only decoded for `main` branch builds
- Secrets are encrypted and only accessible during workflow runs
- Artifacts are automatically deleted after 30 days