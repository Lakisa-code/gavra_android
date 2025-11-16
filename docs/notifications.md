### Quick interactive tooling

We also include a helper to set secrets and copy your `agconnect-services.json` into the project:

```powershell
.\supabase\scripts\set_huawei_secrets.ps1 -HuaweiAppId '<id>' -HuaweiAppSecret '<secret>' -AgconnectPath 'C:\Users\Bojan\Downloads\agconnect-services.json' -SetSecrets -Verify
```

This script will:
 - Copy `agconnect-services.json` to `android/app/`
 - Set Supabase secrets for HUAWEI_APP_ID and HUAWEI_APP_SECRET
 - Verify credentials by requesting a token

Use `-Deploy` if you also want to deploy migrations & functions with `deploy_notifications.ps1`.

# Notifikacije (FCM + Huawei + Lokalno)

Ova dokumentacija objašnjava kako radi novi sistem notifikacija i kako da primenite potrebne server-side promene.

## Šta je promenjeno
- Klijent: Nova `PushService` registruje FCM i Huawei push tokene i upsert-uje mapping `driver_id` -> `player_id` u tabelu `push_players` i postavlja `removed_at=null, is_active=true`.
- Logout sada radi soft-delete (postavlja `removed_at` i `is_active=false`) kako bi se izbeglo brisanje istorije.
- Dodata je nova Supabase migracija koja dodaje `removed_at` i `is_active` na `push_players` tabelu.
- Edge Function `send-push-notification` može prihvatiti `driver_ids` i mapirati ih server-side u aktuelne push token-e (fcm/huawei), filtrisane po `is_active=true`.
   Preporučeno: kada ciljamo specifičnog vozača, koristite `driver_ids` (npr. 'dusan', 'bojan') kako bismo izbegli slanje notifikacija is_active=false korisnicima.
- Edge Function `cleanup-push-players` briše (permanently) soft-deleted zapise starije od X dana (default 30).

## Koraci za deploy (kratko)
1. Primeni migrations (Supabase CLI/Studio)
2. Setuj tajne:
   - `FCM_SERVER_KEY`
   - (`HUAWEI_APP_ID` and `HUAWEI_APP_SECRET`) - optional
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_URL`
3. Deploy functions
4. Zakazati poziv `cleanup-push-players` na dnevnom nivou (kad god odgovara)

## Bezbednost
- `FCM_SERVER_KEY`, `HUAWEI_APP_ID`, `HUAWEI_APP_SECRET` and `SUPABASE_SERVICE_ROLE_KEY` must be stored as secrets on the server and never committed to the repo.

## Huawei (HMS) - Quick Setup

- Add `agconnect-services.json` at `android/app/agconnect-services.json` from AppGallery Connect.
   - To obtain `agconnect-services.json` go to AppGallery Connect > My Apps > app > Project settings and download the `agconnect-services.json` for the Android platform. Place it at `android/app/agconnect-services.json` on your local dev site and do NOT commit to the repo.

### Validate Huawei secrets

- After creating `HUAWEI_APP_ID` and `HUAWEI_APP_SECRET` in AppGallery Connect and setting them as Supabase secrets, you can verify them locally with the included PowerShell helper:

```powershell
# Set env and run verifier (PowerShell)
$env:HUAWEI_APP_ID = '<your-id>'
$env:HUAWEI_APP_SECRET = '<your-secret>'
.\supabase\scripts\verify_huawei_secrets.ps1
```

If the verifier returns a token, your credentials are valid. If not, ensure you used the App-level credentials exactly as created in AppGallery Connect.
- Ensure `huawei_push` plugin is added to `pubspec.yaml` and run `flutter pub get`.
- The `PushService` uses a `MethodChannel` to query and listen for token updates; if you are using a different HMS plugin version, confirm the channel name / methods and adjust as needed.
- Set the Supabase secrets `HUAWEI_APP_ID` and `HUAWEI_APP_SECRET` if you plan to send server-side messages to HMS.

Note: For full HMS support, you must test on Huawei devices (with HMS Core installed) and verify token registration & receipt of messages using the `send-push-notification` Edge Function.

## Testing push delivery (quick guide)

- Deploy migrations and functions (and secrets) as described in `supabase/README.md`.
- On Android/GMS device: verify FCM token is registered in `push_players` table after login, then call `send-fcm-notification` (topic or token) and confirm notification arrives.
- On Huawei device: verify Huawei token is registered in `push_players` table after login, then call `send-push-notification` with `driver_ids` to confirm message arrives.
- For broadcast to all devices, call `send-push-notification` with `segment: 'All'`.
