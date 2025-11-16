# Supabase setup

This folder contains migrations and edge functions used for notifications and other server-side tasks.

1) Apply migrations (run from the Supabase CLI / Studio):

```bash
# If using supabase CLI
supabase db push
# Or run individual migration
supabase migration run
```

2) Set required secrets for functions:

```bash
# FCM Server Key (required)
# FCM Server Key (required)
supabase secrets set FCM_SERVER_KEY=<your-fcm-server-key>
# Optional: FCM v1 OAuth access token (preferred for FCM v1 messaging)
supabase secrets set FCM_V1_ACCESS_TOKEN=<your-fcm-v1-access-token>
# Optional: FCM v1 project id (for v1 usage)
supabase secrets set FCM_PROJECT_ID=<gavra-notif-20250920162521>
# Huawei Push (optional - if you target Huawei devices)
# Steps to obtain HUAWEI credentials:
#  1. Sign in to AppGallery Connect (https://developer.huawei.com/consumer/en/)
#  2. Create an application (or use an existing one) and note the App ID
#  3. Navigate to "AppGallery Connect > My apps > Project settings" and create an App-Level API key (App Secret) or credentials required to send push
#  4. Download `agconnect-services.json` and place it under `android/app/agconnect-services.json` locally (do NOT commit it)

supabase secrets set HUAWEI_APP_ID=<your-huawei-app-id>
supabase secrets set HUAWEI_APP_SECRET=<your-huawei-app-secret>
# Optional: verify your Huawei credentials using provided script
# Example (PowerShell):
# $env:HUAWEI_APP_ID = 'xx'
# $env:HUAWEI_APP_SECRET = 'xx'
# .\supabase\scripts\verify_huawei_secrets.ps1

# Use the interactive helper to set secrets, copy agconnect file, verify, and optionally deploy
# Example (PowerShell):
.\supabase\scripts\set_huawei_secrets.ps1 -HuaweiAppId '<id>' -HuaweiAppSecret '<secret>' -AgconnectPath 'C:\Users\Bojan\Downloads\agconnect-services.json' -SetSecrets -Verify -Deploy

# Non-interactive automation
Alternatively, use the `auto_set_deploy.ps1` script to set secrets and deploy in a single non-interactive command (or call from CI):

```powershell
.\supabase\scripts\auto_set_deploy.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<service_role_key>' -FcmServerKey '<fcm-key>' -HuaweiAppId '<id>' -HuaweiAppSecret '<secret>' -AgconnectPath 'path\to\agconnect-services.json' -GoogleServiceAccountJson '<json contents or file path>' -FcmProjectId '<id>' -VerifyHuawei -Deploy
```

## CI: GitHub Actions

We provide a GitHub Actions workflow that can be invoked manually to set secrets and run the deployment.
Add the following secrets to your GitHub repo Settings → Secrets:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- FCM_SERVER_KEY
- (Optional) HUAWEI_APP_ID
- (Optional) HUAWEI_APP_SECRET
- (Optional) GOOGLE_SERVICE_ACCOUNT_JSON
 (Optional) FCM_PROJECT_ID

You can optionally provide `AGCONNECT_JSON` (the content of `agconnect-services.json`) in the repo secrets; the workflow will write it locally before deploy.

Note: If you previously set any legacy push provider secrets in Supabase (e.g., for a third-party push provider), review and remove them from Supabase Secrets to avoid accidental usage or exposure.

Local test helpers
------------------
We added a couple of scripts to run quick manual acceptance tests and checks:

- `supabase/scripts/test_push_acceptance.ps1` — triggers `send-push-notification` to a `driver_id` or a manual `token`.
- `supabase/scripts/check_push_players.ps1` — queries `push_players` for a driver and prints a provider summary.

Examples (PowerShell):
```powershell
# Check that a driver has push tokens
pwsh ./supabase/scripts/check_push_players.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<role>' -DriverId 'dusan'

# Send a manual acceptance push
pwsh ./supabase/scripts/test_push_acceptance.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<role>' -DriverId 'dusan'

Notes:
- `check_push_players.ps1` accepts `-FailIfNone` which makes it exit with a non-zero return code when no active tokens are found; this is useful for CI validation.
- CI 'Deploy Notifications' workflow uses `TEST_TARGET_DRIVER_ID` repo secret to validate a test driver presence before and after deploy and fail the job if no tokens exist.
```

To run the workflow manually from the Actions tab, choose `Deploy Notifications (Supabase)` and run.
CI pipeline step flow summary:
- Pre-deploy: check the `push_players` token counts for the `TEST_TARGET_DRIVER_ID` if provided (non-failing; just logs)
- Deploy: set secrets and deploy migrations & edge functions
- Post-deploy: call the `send-push-notification` Edge function for the `TEST_TARGET_DRIVER_ID` and check `push_players` for active tokens and function response

CI and Safety recommendations:
- Add a secret `TEST_TARGET_DRIVER_ID` with a driver id you use for CI verification (optional). The workflow will attempt a single acceptance test.
-- Remove old legacy push provider secrets from Supabase if you previously set them. Example commands:
	```bash
	# Remove legacy push provider secrets if present
	supabase secrets remove LEGACY_PUSH_REST_KEY || true
	supabase secrets remove LEGACY_PUSH_APP_ID || true
	```
# Supabase service role key (required for driver_id mapping or cleanup)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
supabase secrets set SUPABASE_URL=<your-supabase-url>
# Optional: Provide Google service account JSON to allow automatic FCM v1 access token generation.
supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='<SERVICE_ACCOUNT_JSON_CONTENT_HERE>'
```

3) Deploy functions:

```bash
supabase functions deploy send-fcm-notification
supabase functions deploy send-push-notification
supabase functions deploy cleanup-push-players
```

4) Configure scheduled runs:

Add a scheduled job to call `cleanup-push-players` periodically (e.g., daily) using your CRON infrastructure, or use the hosted schedule feature if available.

Notes
- The new migration adds `removed_at` and `is_active` to `push_players` so we can soft-delete on logout and still have historical info for analytics if needed.
- After applying the migration, the app now sets `is_active=true` on upsert and marks `removed_at`/`is_active=false` on logout.

Deployment note:
- If you want the Edge function to generate FCM v1 OAuth access tokens automatically, provide `GOOGLE_SERVICE_ACCOUNT_JSON` either via env (e.g., `Get-Content -Raw`) or via the `deploy_notifications.ps1` parameter.
Example PowerShell usage to pass JSON:
```powershell
$env:GOOGLE_SERVICE_ACCOUNT_JSON = Get-Content -Raw path\to\service-account.json
./supabase/deploy_notifications.ps1
```
