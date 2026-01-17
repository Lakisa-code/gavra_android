# CI Workflows — Notes

This file contains quick notes about the repository's release workflows.

- **Google Play** — the `google-closed-testing.yml` workflow builds an **AAB** and uploads it to the Alpha (Closed Testing) track. AAB is preferred for Play uploads.
- **Huawei AppGallery** — the `huawei-production.yml` workflow builds an **APK** and uploads it to AppGallery. By default this workflow now **submits the uploaded APK for review automatically** (`submit_for_review` default is `true`). You can override the behaviour when dispatching the workflow if you need to only upload without submitting.
- **iOS / App Store** — the `ios-production.yml` workflow reads version from `pubspec.yaml` and uploads the IPA; App Store Connect credentials are required as secrets.

Secrets to configure for CI:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`
- `AGC_CLIENT_ID`, `AGC_CLIENT_SECRET`, `AGC_APP_ID` (for Huawei)
- `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_PRIVATE_KEY`, `CERTIFICATE_PRIVATE_KEY` (for iOS)

If you'd like, I can extend the README with examples of how to dispatch the release workflow and an example `gh` CLI command.
