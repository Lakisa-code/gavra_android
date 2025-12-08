// Supabase Edge Function (Node) - send-push-notification
// Expected input examples:
// { title, body, tokens: [{token, provider}] }
// or { title, body, segment: 'All' }

// Use undici fetch (small, actively maintained fetch implementation)
let fetch = null;
try {
    fetch = require('undici').fetch;
} catch (e) {
    // fallback to global fetch if available
    if (typeof globalThis.fetch === 'function') fetch = globalThis.fetch;
}
if (!fetch) throw new Error('fetch API not available in runtime — install undici or use a runtime with global fetch');

// Firebase Admin SDK for FCM v1 API
let admin = null;
let fcmInitialized = false;
try {
    admin = require('firebase-admin');
} catch (e) {
    // Firebase Admin not installed - will use legacy API as fallback
}

// Initialize Firebase Admin if credentials are available
async function ensureFirebaseInitialized() {
    if (fcmInitialized) return true;
    if (!admin) return false;

    try {
        const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!serviceAccountJson) return false;

        const serviceAccount = JSON.parse(serviceAccountJson);

        if (admin.apps.length === 0) {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
        }
        fcmInitialized = true;
        return true;
    } catch (e) {
        return false;
    }
}

// Helper: send to FCM via v1 API (recommended)
async function sendFcmV1(token, payload) {
    if (!await ensureFirebaseInitialized()) {
        return { status: 'firebase-not-initialized' };
    }

    try {
        const message = {
            notification: {
                title: payload.title,
                body: payload.body
            },
            data: payload.data || {},
            token: token
        };

        const response = await admin.messaging().send(message);
        return { status: 200, messageId: response };
    } catch (e) {
        return { status: 'error', error: e.message };
    }
}

// Legacy FCM helper (fallback if Firebase Admin not available)
async function sendFcmLegacy(serverKey, token, payload) {
    const resp = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `key=${serverKey}`,
        },
        body: JSON.stringify({ to: token, notification: payload }),
    });
    return resp;
}

// Huawei (AGC) helper notes & optional SDK initialization
// The preferred approach for server-side integration is to use the
// @agconnect/common-server SDK and the client JSON credential file
// (agc-apiclient-xxx.json) provided by AppGallery Connect. For environments
// where the SDK cannot be installed, the function falls back to the
// OAuth2 + REST API calls shown below.
// The function will attempt to initialize the SDK (if installed) using the
// environment variable AGC_APICLIENT_JSON (a JSON string) or
// AGC_APICLIENT_JSON_PATH (path to the JSON) at runtime.

let AGCClient = null;
let CredentialParser = null;
let agcInitialized = false;
try {
    // try to load server SDK if it's been installed in the function runtime
    const agc = require('@agconnect/common-server');
    AGCClient = agc.AGCClient || agc.AGCClient || null;
    CredentialParser = agc.CredentialParser || agc.CredentialParser || null;
} catch (e) {
    // SDK not present in runtime — we will use REST fallback below
}

// Simple cached token to reduce token fetches during bursts
const _huaweiTokenCache = { accessToken: null, expiresAt: 0 };

async function ensureAgcInitialized() {
    if (agcInitialized) return true;
    if (!AGCClient || !CredentialParser) return false;

    try {
        const agcJsonRaw = process.env.AGC_APICLIENT_JSON || process.env.AGC_APICLIENT_JSON_PATH;
        if (!agcJsonRaw) return false;

        let jsonObj = null;
        if (agcJsonRaw.trim().startsWith('{')) {
            jsonObj = JSON.parse(agcJsonRaw);
        } else {
            jsonObj = require(agcJsonRaw);
        }

        const credential = CredentialParser.toCredential(jsonObj);
        AGCClient.initialize(credential);
        agcInitialized = true;
        return true;
    } catch (e) {
        // initialization failed; we'll continue with REST flow
        return false;
    }
}

async function getHuaweiAccessTokenWithCache(clientId, clientSecret) {
    // if cached and not expired, return
    const now = Date.now();
    if (_huaweiTokenCache.accessToken && _huaweiTokenCache.expiresAt > now + 5000) {
        return _huaweiTokenCache.accessToken;
    }

    const tokenResp = await fetch('https://oauth-login.cloud.huawei.com/oauth2/v3/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=client_credentials&client_id=${encodeURIComponent(clientId)}&client_secret=${encodeURIComponent(clientSecret)}`,
    });

    if (!tokenResp.ok) {
        const txt = await tokenResp.text();
        throw new Error('token-failed: ' + txt);
    }

    const tokenData = await tokenResp.json();
    const accessToken = tokenData.access_token;
    const expiresIn = tokenData.expires_in || 3600;
    _huaweiTokenCache.accessToken = accessToken;
    _huaweiTokenCache.expiresAt = Date.now() + (expiresIn * 1000);
    return accessToken;
}

module.exports = async (req, res) => {
    try {
        const body = await req.json();
        const { title, body: messageBody, tokens, serverKeys, data } = body || {};

        if (!title || !messageBody) return res.status(400).json({ error: 'title and body required' });

        // tokens: [{ token, provider }]
        if (!tokens || !Array.isArray(tokens)) return res.status(400).json({ error: 'tokens array required' });

        const results = [];

        for (const t of tokens) {
            if (!t || !t.token || !t.provider) continue;
            if (t.provider === 'fcm') {
                // Try FCM v1 API first (recommended), fallback to legacy if not configured
                const v1Result = await sendFcmV1(t.token, { title, body: messageBody, data: data || {} });

                if (v1Result.status === 200 || v1Result.messageId) {
                    results.push({ provider: 'fcm', status: 200, api: 'v1', messageId: v1Result.messageId });
                } else if (v1Result.status === 'firebase-not-initialized') {
                    // Fallback to legacy API
                    const serverKey = serverKeys?.fcm || process.env.FCM_SERVER_KEY;
                    if (!serverKey) {
                        results.push({ provider: 'fcm', status: 'no-credentials' });
                        continue;
                    }
                    const resp = await sendFcmLegacy(serverKey, t.token, { title, body: messageBody });
                    results.push({ provider: 'fcm', status: resp.status, api: 'legacy' });
                } else {
                    results.push({ provider: 'fcm', status: v1Result.status, error: v1Result.error });
                }
            } else if (t.provider === 'huawei') {
                // Try to send via Huawei Cloud Push REST API using agc-apiclient credentials
                const agcJsonRaw = process.env.AGC_APICLIENT_JSON || process.env.AGC_APICLIENT_JSON_PATH;
                const agcAppId = process.env.AGC_APP_ID || serverKeys?.huaweiAppId;

                if (!agcJsonRaw || !agcAppId) {
                    results.push({ provider: 'huawei', status: 'missing-config' });
                    continue;
                }

                // Parse client credentials (try JSON parse first, else assume a file path)
                let clientId = null;
                let clientSecret = null;
                try {
                    let jsonObj = null;
                    if (agcJsonRaw.trim().startsWith('{')) {
                        jsonObj = JSON.parse(agcJsonRaw);
                    } else {
                        // runtime path to file
                        jsonObj = require(agcJsonRaw);
                    }
                    clientId = jsonObj.client_id || jsonObj.clientId;
                    clientSecret = jsonObj.client_secret || jsonObj.clientSecret;
                } catch (e) {
                    results.push({ provider: 'huawei', status: 'invalid-agc-credentials', error: String(e) });
                    continue;
                }

                if (!clientId || !clientSecret) {
                    results.push({ provider: 'huawei', status: 'missing-client-id-secret' });
                    continue;
                }

                try {
                    // Optional: try to init AGC SDK (if present) — helps server SDK users
                    await ensureAgcInitialized();

                    // 1) obtain access token (cached helper)
                    let accessToken;
                    try {
                        accessToken = await getHuaweiAccessTokenWithCache(clientId, clientSecret);
                    } catch (e) {
                        results.push({ provider: 'huawei', status: 'token-failed', details: String(e) });
                        continue;
                    }

                    // 2) send push to Huawei API
                    // If AGC SDK is initialized, prefer using the SDK's push API (safe try/catch)
                    if (agcInitialized) {
                        try {
                            // attempt a few reasonable SDK call patterns
                            const agcPkg = require('@agconnect/common-server');
                            const PushMessage = agcPkg.PushMessage || agcPkg.PushMessage || null;

                            // messaging() is a common pattern; try other alternatives defensively
                            const clientMessaging = (typeof AGCClient.messaging === 'function' ? AGCClient.messaging() :
                                (typeof AGCClient.getService === 'function' ? AGCClient.getService('push') : null));

                            if (clientMessaging && typeof clientMessaging.send === 'function') {
                                // If PushMessage class exists, construct it, otherwise pass plain object
                                const sdkPayload = PushMessage ? new PushMessage({ message: { notification: { title, body: messageBody }, token: [t.token] } }) : { message: { notification: { title, body: messageBody }, token: [t.token] } };
                                const sdkResp = await clientMessaging.send(sdkPayload);
                                // best-effort stringify
                                results.push({ provider: 'huawei', status: 'sdk', details: String(sdkResp) });
                                continue; // next token
                            }
                        } catch (e) {
                            // SDK call failed — we fall back to REST below
                        }
                    }
                    // NOTE: We send one token per request to keep example simple.
                    const pushUrl = `https://push-api.cloud.huawei.com/v1/${agcAppId}/messages:send`;
                    const pushPayload = {
                        message: {
                            notification: { title, body: messageBody },
                            token: [t.token]
                        }
                    };

                    const pushResp = await fetch(pushUrl, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            Authorization: `Bearer ${accessToken}`,
                        },
                        body: JSON.stringify(pushPayload),
                    });

                    const pushText = await pushResp.text();
                    results.push({ provider: 'huawei', status: pushResp.status, details: pushText });
                } catch (e) {
                    results.push({ provider: 'huawei', status: 'error', error: String(e) });
                }
            }
        }

        return res.status(200).json({ success: true, results });
    } catch (e) {
        return res.status(500).json({ error: e.message || e.toString() });
    }
};
