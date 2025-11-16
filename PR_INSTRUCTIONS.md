# PR & Deployment instructions (Draft)

Title: feat: Migrate to FCM + Huawei + push_players; Add server-side push sending & cleanup

Description:
- Adds `push_players` table for multi-provider push tokens (FCM/Huawei). The repository uses `push_players` and supports migrating any legacy provider data to `push_players`.

Testing:

Example: invoke the `send-push-notification` function with a body to target driver(s):
```
supabase functions invoke send-push-notification --body "{ 'title': 'Test', 'body': 'Hello', 'driver_ids': ['bojan'] }"
```

Verifications:
1. On Android device with Google Play Services (GMS): ensure the device receives FCM topic message and server push via `send-push-notification`.
2. On Huawei device (HMS): ensure the device receives push if `huawei_push` plugin is configured and `HUAWEI_APP_ID`/`HUAWEI_APP_SECRET` are set.

Notes:

