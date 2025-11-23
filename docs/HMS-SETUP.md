Server-side setup (Supabase / CI) — secure your AGC API client
---------------------------------------------------------------

- You will likely want to send push messages server-side using the AGC Server SDK.
- Create an API client in AppGallery Connect -> Project settings -> Server SDK -> Create API client.
- Download the `agc-apiclient-xxx.json` file (this contains your client_id and client_secret).
- Do NOT commit this file to git. Instead:
  - Store its contents in your server secret store (Supabase secrets, CI variables, or your MCP server). For Supabase Edge Functions use a secret name like `AGC_APICLIENT_JSON`.
  - Alternatively, upload the `agc-apiclient-xxx.json` to your server and reference its path in your function environment (e.g., `/var/secrets/agc-apiclient.json`) and give the function read access.

Supabase Edge Functions — minimal guidance
-----------------------------------------
1. Create two Edge Functions: `register-push-token` and `send-push-notification`.
2. `register-push-token` stores tokens in a `push_tokens` table. It expects `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in environment.
3. `send-push-notification` can route messages to FCM or HMS. For FCM you need `FCM_SERVER_KEY` in env. For HMS use `AGC_APICLIENT_JSON` (or credentials stored with a secret name) and install the AGC Server SDK on your function runtime.

Example environment variables (set in Supabase UI or your CI):
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- FCM_SERVER_KEY (if you still use FCM server sends)
- AGC_APICLIENT_JSON (the **entire** JSON string; read it from env in your function code)
- AGC_APP_ID (the Android appId from `agconnect-services.json`, required for server push REST API)

I added safe stubs in `supabase/functions/` in this repo with placeholders — they are NOT complete production code, but are a working starting point.

Huawei Mobile Services (HMS) — quick setup for this repo

What you need:
1. A project in Huawei AppGallery Connect
2. The `agconnect-services.json` file for your Android app (download from AppGallery Connect)

Steps:

1) In AppGallery Connect -> Your project -> Project settings -> App information -> Android app -> Download `agconnect-services.json`. 

2) Copy the downloaded file to:
  android/app/agconnect-services.json (or use `android/app/agconnect-services.json.example` as a safe starting template — fill the real file on your machine and do NOT commit it)

   Note: `agconnect-services.json` is added to `.gitignore` in this repo (do NOT commit it unless you really want to share credentials). Instead keep it on your local machine or in CI secret storage.

3) If you haven't already, add the AGC Gradle plugin to the top-level Gradle configuration (only needed on some setups). Example in `android/build.gradle.kts`:

plugins {
  id("com.google.gms.google-services") version "4.3.15" apply false
  // If build fails due to missing AGC plugin, uncomment and use a matching AGC plugin version:
  // id("com.huawei.agconnect") version "1.4.2.300" apply false
}

4) Rebuild your app. On devices without Google Play Services, this app will attempt to use Huawei Push copies (HMS) instead of Firebase (FCM).

Additional helpful info — what you will find inside `agconnect-services.json` and where to get other values

- appId: the App ID for your Android app in AppGallery Connect
- packageName: must match `applicationId` in `android/app/build.gradle.kts` (e.g., com.gavra013.gavra_android)
- client_id / client_secret: used for OAuth2 / backend flows (keep secret; do NOT commit)
- api_key / server_key / push credentials: needed if you plan server-side push to HMS

Where to find these in AppGallery Connect
- App information -> get the App ID, package name and download the `agconnect-services.json`.
- AppGallery Connect -> Project settings -> API -> Create an "AppGallery Connect" API key if you need server-side API access. Keep client_secret in a secure place (CI secrets or vault).

CI / GitHub Actions (example)
---------------------------------
If you want to publish builds from GitHub Actions to AppGallery Connect you will need to add the following repository secrets:

- AGC_CLIENT_ID — the API client id (from your AppGallery Connect API credentials)
- AGC_CLIENT_SECRET — the API client secret
- AGC_APP_ID — the App ID of the Android app you're publishing

The repo includes a workflow template `.github/workflows/publish-to-appgallery.yml` and helper `.github/scripts/publish-to-appgallery.sh`.

Quick helper scripts (local)
----------------------------
If you want to add the required secrets to GitHub and Supabase from a local `agc-apiclient-xxx.json` file, the repo includes helper scripts in `scripts/`:

- PowerShell: `scripts/add-agc-secrets.ps1` — reads a local JSON and sets GitHub Action secrets (via `gh`) and Supabase secrets (via `supabase` CLI).
- Bash: `scripts/add-agc-secrets.sh` — same as above, requires `jq`, `gh`, and optionally `supabase`.
- Trigger scripts: `scripts/trigger-publish.ps1` and `scripts/trigger-publish.sh` — create and push a tag to trigger the publish workflow.

Example usage (PowerShell):
```pwsh
.\scripts\add-agc-secrets.ps1 -JsonPath 'C:\Users\Bojan\Downloads\agc-apiclient-1825050424189692224-b9c8e8b243ff4b7ca3e1a188f0aa2325.json'
.\scripts\trigger-publish.ps1 -TagName v1.0.0 -Message "Test publish"
```

Important: these scripts do NOT commit secrets into the repo — they call `gh secret set` and/or `supabase secrets set` and require you to be authenticated locally with those CLIs.
CI notes — AGC CLI or REST
--------------------------------
The publish workflow will try to install a known CLI (AGC / hms-publish-tool / other heuristics) in the runner. If a CLI binary is available it will be used to upload and publish the artifact (recommended).

If the runner does not have a CLI installed or installation fails for your environment, the workflow falls back to a conservative REST flow implemented in `.github/scripts/publish-to-appgallery.sh` which will attempt to initiate an upload, upload the AAB, and commit the upload. Because AppGallery Connect APIs can vary by region, you may need to set `AGC_API_BASE` in workflow secrets to match your account (this is optional and defaults to the common public API base).

To enable CI publishing (recommended):
- Add the following repo secrets: `AGC_CLIENT_ID`, `AGC_CLIENT_SECRET`, `AGC_APP_ID`.
- Optionally add `AGC_API_BASE` if your AppGallery Connect region uses a different endpoint.

The script is conservative and will not publish unless the upload/commit returns expected values — test in a non-production AppGallery project first.
The helper currently obtains an OAuth token and acts as a safe template — complete the script with the AppGallery file upload steps or use the official AGC CLI tool.

Security reminders
- `agconnect-services.json` is intentionally added to `.gitignore` in this repository and should not be committed. Treat any client_secret or private keys like other production secrets (store in CI secrets, environment variables or a secrets manager).

Testing locally
- Install the `agconnect-services.json` in `android/app/`. Build and run on a Huawei device without Google Play Services. Check `adb logcat` for HMS push logs or initialization diagnostics.

If you want, I can:
- add an example placeholder file `android/app/agconnect-services.json.example` with the fields you'll need to fill (safe: no secrets), and
- add a small README snippet with exact AppGallery Connect paths and short test commands (adb logcat lines to watch) — tell me if you want me to add those now.

Quick troubleshooting: If the app still doesn't start on a device without Google Play Services, share the runtime log (adb logcat) and I can help diagnose.
