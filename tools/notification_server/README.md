Minimal notification server for Gavra Android

This server provides two endpoints (protected by `X-API-KEY`):
- POST /api/send-fcm
  - body: { token, title, body, data }
  - sends an FCM message via `firebase-admin` using the service account configured by `GOOGLE_APPLICATION_CREDENTIALS` or ADC
- POST /api/onesignal/notify
  - body: { headings, contents, include_player_ids, data }
  - forwards to OneSignal REST API using `ONE_SIGNAL_REST_KEY` and `ONE_SIGNAL_APP_ID`

Setup (local):
1. cd tools/notification_server
2. npm install
3. Set environment variables in PowerShell (session):
   $env:SERVER_API_KEY = "your-strong-secret"
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
   $env:ONE_SIGNAL_REST_KEY = "your-onesignal-rest-key"
   $env:ONE_SIGNAL_APP_ID = "your-onesignal-app-id"
4. npm start

Security notes:
- Do NOT commit any secrets to git.
- For production, use Cloud Run + Secret Manager or similar.
- Replace the simple X-API-KEY middleware with JWT or Cloud IAM for better security.

Local .env usage:
- A `.env` file is supported for local development. A sample `.env` is included in this folder but it is gitignored.
- For local testing the provided Google API key was placed in `GOOGLE_API_KEY` in `.env` (this is for convenience only — the server itself uses service account credentials via `GOOGLE_APPLICATION_CREDENTIALS`).

Remember: rotate any keys you commit by accident and never store OneSignal REST keys or service-account JSON files in the repository.
