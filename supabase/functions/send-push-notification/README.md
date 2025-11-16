# send-push-notification

Supabase Edge function that accepts a payload and sends push notifications via FCM or Huawei Push (HMS). It looks up target tokens in `push_players` and groups by `provider`.

Deployment:
```
supabase secrets set FCM_SERVER_KEY=<your-fcm-server-key>
supabase secrets set HUAWEI_APP_ID=<your-huawei-app-id>
supabase secrets set HUAWEI_APP_SECRET=<your-huawei-secret>
# Optional: FCM v1 server-side OAuth access token
supabase secrets set FCM_V1_ACCESS_TOKEN=<optional-fcm-v1-access-token>
# Optional (recommended): Provide a Google service account JSON as a secret to allow the function
# to automatically generate FCM v1 OAuth tokens. This avoids manual token rotation.
# The service account JSON should be the entire JSON content of the service account.
supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='<SERVICE_ACCOUNT_JSON_CONTENT_HERE>'
# Optional: FCM V1 project id (for v1 usage)
supabase secrets set FCM_PROJECT_ID=<project-id-for-fcm-v1>
supabase functions deploy send-push-notification
```

Usage sample:
```
curl -X POST 'https://<project>.functions.supabase.co/send-push-notification' -H "Content-Type: application/json" -d '{"title":"Test","body":"Hello","driver_ids":[123,456]}'
```

Notes: If `FCM_V1_ACCESS_TOKEN` is configured it will be used for FCM v1 sending (preferable); otherwise the function falls back to `FCM_SERVER_KEY` (legacy).

How to generate an `FCM_V1_ACCESS_TOKEN` (one-time or automated):
- Create a service account with the role `Firebase Admin` or similar.
- Use `gcloud auth activate-service-account --key-file=service-account.json` then run:
	```bash
	gcloud auth print-access-token
	```
	This gives you a bearer token valid for a short period. You can set it as `FCM_V1_ACCESS_TOKEN` using the `supabase secrets set` CLI; you can automate rotating the token via a script.

	Or: Provide `GOOGLE_SERVICE_ACCOUNT_JSON` and `FCM_PROJECT_ID` instead. The function will use the Google service account JSON to generate a valid OAuth access token automatically; this is the recommended approach for automation and avoiding manual rotation.

Notes:
- Ensure `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_URL` are set in secrets for the function to query `push_players`.
- Tune Huawei send logic to support batch sends or use the official SDK for higher throughput.
