# How to enable CI-signed releases (keystore + secrets)

This repository includes a GitHub Actions workflow (.github/workflows/signed-release-apk.yml) that will build a signed, updatable APK when the required signing secrets are present.

We intentionally do not store your keystore in the repository. Instead, CI will read the following GitHub Secrets and create the keystore and `android/key.properties` at build time:

Required repository secrets (set in Settings → Secrets → Actions):

- KEYSTORE_BASE64 — base64-encoded .keystore file (binary) (required for automatic signing)
- KEYSTORE_PASSWORD — store password for the keystore
- KEY_ALIAS — key alias inside the keystore
- KEY_PASSWORD — password for the private key

Optional / recommended:
- GITHUB_TOKEN — already provided in Actions; used for creating releases when building on tags

How to create KEYSTORE_BASE64 (example, local machine):

1. Place your keystore file somewhere on your machine (example: gavra-release-key-production.keystore).
2. Convert to base64 and copy to the secret:

```bash
# macOS / Linux
base64 -w 0 gavra-release-key-production.keystore > gavra-release-key-production.keystore.base64

# Windows PowerShell (single-line base64)
[Convert]::ToBase64String([IO.File]::ReadAllBytes('path\\to\\gavra-release-key-production.keystore')) > gavra-release-key-production.keystore.base64
```

Open the generated file, copy the single-line base64 content and paste into the `KEYSTORE_BASE64` repository secret value.

What the workflow does:

- When `KEYSTORE_BASE64` and other signing secrets are present, the workflow decodes the keystore into `gavra-release-key-production.keystore` at the repository root for the job run.
- It writes `android/key.properties` (only inside the runner — not committed) with the secrets so the Gradle signing config can pick them up.
- It builds a signed release APK and uploads the APK artifacts into the workflow run (Artifacts page) so you can download them.
- If the run is triggered by a tag, it will attempt to create a GitHub release and attach the build artifact.

Important security note:
- Currently `android/key.properties` in this repository contains plaintext passwords. This is insecure — after you add the secrets and confirm CI is working, you should *remove `android/key.properties` from the repository or replace its contents with a template* and add it to `.gitignore` to avoid leaking credentials.

If you'd like, I can:
- remove `android/key.properties` from the repository and add a `key.properties.example` (you must confirm you want that change),
- or leave current files intact and only use the new workflow (your decision).

If you're ready I can implement the secrets in this repo (I can't add secrets for you) and then run a manual workflow_dispatch to create a signed APK — you'll need to add `KEYSTORE_BASE64` and the other secrets in the repo first.
