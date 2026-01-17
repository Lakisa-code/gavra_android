# CI Workflows — Notes

This file contains quick notes about the repository's release workflows.

- **Google Play** — the `google-closed-testing.yml` workflow builds an **AAB** and uploads it to the Alpha (Closed Testing) track. AAB is preferred for Play uploads.
- **Huawei AppGallery** — the `huawei-production.yml` workflow builds an **APK** and uploads it to AppGallery. By default this workflow now **submits the uploaded APK for review automatically** (`submit_for_review` default is `true`). You can override the behaviour when dispatching the workflow if you need to only upload without submitting.
- **iOS / App Store** — the `ios-production.yml` workflow reads version from `pubspec.yaml` and uploads the IPA; App Store Connect credentials are required as secrets.

Dry-run & orchestrated releases
--------------------------------

To verify what the orchestrator will do without performing uploads or submissions, run the `release-all-platforms.yml` workflow in dry-run mode. Use `confirm=false` to prevent any commits or pushes, and set the `submit_*` flags to `false` to avoid triggering platform workflows. Example using the `gh` CLI:

```bash
gh workflow run .github/workflows/release-all-platforms.yml \
	--ref main \
	-f confirm=false \
	-f bump_type=none \
	-f submit_ios=false \
	-f submit_google=false \
	-f submit_huawei=false \
	-f release_notes="Dry run - verify payloads"
```

What to look for in the logs:
- The `prepare-version` job prints the **Final version** message (`📌 Final version: X.Y.Z (BUILD)`). This is the version that will be forwarded to platform workflows when `confirm=true` or `submit_*` are enabled.
- If you later set `submit_*` to `true` the orchestrator will dispatch platform workflows and pass `version_name`/`version_code`, `release_notes`, and `force_replace_review`.

Flags summary:
- `confirm` - must be `true` to commit/perform bump changes (default: `false`).
- `submit_ios`, `submit_google`, `submit_huawei` - control whether platform workflows are dispatched (default: `false`).
- `force_replace_review` - when `true` orchestrator requests platform workflows to replace existing in-review submissions (dangerous). Use with caution.

If you'd like, I can run a dry-run now and paste the relevant log output showing the computed version.

Secrets to configure for CI:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`
- `AGC_CLIENT_ID`, `AGC_CLIENT_SECRET`, `AGC_APP_ID` (for Huawei)
- `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_PRIVATE_KEY`, `CERTIFICATE_PRIVATE_KEY` (for iOS)

If you'd like, I can extend the README with examples of how to dispatch the release workflow and an example `gh` CLI command.
