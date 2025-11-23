Supabase Edge Functions - push helpers
=====================================

Included functions (stubs):

- register-push-token
  - Accepts JSON { provider, token, user_id? }
  - Stores token in a Supabase table `push_tokens` using the service role key

- send-push-notification
  - Accepts { title, body, tokens: [{token, provider}] }
  - Sends via FCM (if FCM_SERVER_KEY provided) and contains a placeholder for Huawei (AGC) sending

Security and secrets
--------------------
- Do NOT commit credentials to git. Use Supabase project secrets (Settings → API → Project API keys / Secrets) or your CI secret store.
- Required environment vars for production deployment:
  - SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY
  - FCM_SERVER_KEY (if using FCM sends)
  - AGC_APICLIENT_JSON (the server AGC credentials JSON *string* or file path to the JSON on your server)

  Notes & examples
  -----------------
  - For Supabase Edge Functions set a secret named `AGC_APICLIENT_JSON` whose value is the entire JSON string from your `agc-apiclient-xxx.json` file.
  - On GitHub Actions set `AGC_CLIENT_ID` and `AGC_CLIENT_SECRET` (or store the JSON blob in `AGC_APICLIENT_JSON`) and `AGC_APP_ID` as repository secrets.
  - The function code supports both: a direct JSON string in `AGC_APICLIENT_JSON` or a runtime path via `AGC_APICLIENT_JSON_PATH`.

AGC / Huawei notes
------------------
- To send Huawei pushes from the server you should use the AGC Server SDK or the cloud push REST API.
- The Node example for AGC server side uses `@agconnect/common-server` and needs the agc-apiclient JSON to initialize:

  var { AGCClient, CredentialParser } = require('@agconnect/common-server');
  var credential = CredentialParser.toCredential(process.env.AGC_APICLIENT_JSON_PATH || '/path/to/agc-apiclient.json');
  AGCClient.initialize(credential);

- The repo contains `agc-apiclient.example.json` as a template — copy it and fill values in your secure environment, don't commit real data.

Deployment
----------
Use the Supabase CLI or UI to deploy the edge functions and set required environment variables.

Running tests locally
---------------------
To quickly smoke-test the `send-push-notification` function locally, you can run the included script in the function folder:

```bash
cd supabase/functions/send-push-notification
npm install
npm run test:smoke
```

This will exercise validation branches (missing title/body, bad tokens shape) — it does not send live pushes unless you configure env vars for FCM/Huawei.
