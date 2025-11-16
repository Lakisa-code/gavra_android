# Changelog for Notification Changes (FCM + Huawei + push_players)

## 2025-11-16 — FCM + Huawei migration & push_players

- Created new Supabase migration `push_players` (previous legacy provider entries were migrated historically if present).
- Added `cleanup-push-players` Edge Function to permanently delete soft-deleted `push_players` rows older than N days.
- Updated `AuthManager.logout` to soft-delete mappings in `push_players`.
- Updated documentation and deployment scripts to use `FCM_SERVER_KEY` and (optional) Huawei credentials.

---

### Notes
- Ensure `FCM_SERVER_KEY`, `HUAWEI_APP_ID`, `HUAWEI_APP_SECRET` (optional), `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_URL` are set in Supabase secrets before deploying.
- Migration must be run to use `is_active` and `removed_at` columns.
