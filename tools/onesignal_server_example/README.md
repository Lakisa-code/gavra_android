This is a minimal example Node.js server that forwards notification requests from the client to OneSignal.

Why use this?
- Keeps your OneSignal REST API key off the client.
- Lets your server enforce access control and additional business logic.

Quick start:

1. Install dependencies:

```bash
npm install
```

2. Set environment variables (Linux/Mac):

```bash
export ONE_SIGNAL_REST_KEY=your_rest_api_key_here
export ONE_SIGNAL_APP_ID=your_app_id_here
```

On Windows PowerShell:

```powershell
$env:ONE_SIGNAL_REST_KEY = 'your_rest_api_key_here'
$env:ONE_SIGNAL_APP_ID = 'your_app_id_here'
```

3. Run the server:

```bash
npm start
```

4. From the Flutter app, set `RealtimeNotificationService._oneSignalServerUrl` to the server URL, e.g. `https://yourserver.example.com/api/notify`.

Security notes:
- Protect this endpoint with authentication (API key, JWT, IP restrictions) before using in production.
- Rate-limit and validate incoming requests to avoid abuse.
