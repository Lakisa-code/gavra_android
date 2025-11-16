# cleanup-push-players

Cleanup function to permanently delete `push_players` records older than a given threshold where `is_active` is false.

Deploy with:
```
supabase functions deploy cleanup-push-players
```

Invoke sample (use your HTTP client of choice):
```
POST https://<project>.functions.supabase.co/cleanup-push-players
Body: { "days": 30 }
```
