# 🔒 OneSignal Notification Sender - Supabase Edge Function

Esta función maneja el envío seguro de notificaciones OneSignal desde el servidor.

## Deployment

```bash
# Deploy edge function
supabase functions deploy send-onesignal-notification

# Set environment variable (REST API key)
supabase secrets set ONESIGNAL_REST_KEY=dymepwhpkubkfxhqhc4mlh2x7
```

## Usage

```typescript
// From Flutter app
final response = await supabase.functions.invoke(
  'send-onesignal-notification',
  body: {
    'app_id': '4fd57af1-568a-45e0-a737-3b3918c4e92a',
    'title': 'Notification title',
    'body': 'Notification body',
    'segment': 'All', // or specific player_id
    'data': {'key': 'value'} // optional
  },
);
```

## Response

```json
{
  "success": true,
  "notification_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "recipients": 42
}
```

## Security Benefits

- ✅ OneSignal REST API key je sakriven na server-side
- ✅ CORS properly configured
- ✅ Error handling i validation
- ✅ Logging za debugging
- ✅ Fallback strategy u Flutter app-u