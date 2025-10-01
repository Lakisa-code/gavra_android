// Minimal notification server for FCM and OneSignal forwarding
require('dotenv').config(); // load .env in development
const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const axios = require('axios');

const app = express();
app.use(bodyParser.json());

// Required env vars (set these on server, do NOT commit)
const SERVER_API_KEY = process.env.SERVER_API_KEY;
const ONE_SIGNAL_REST_KEY = process.env.ONE_SIGNAL_REST_KEY;
const ONE_SIGNAL_APP_ID = process.env.ONE_SIGNAL_APP_ID;
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY; // optional helper for docs

// Initialize firebase-admin using application default credentials
try {
  if (!admin.apps.length) {
    // firebase-admin will try to use GOOGLE_APPLICATION_CREDENTIALS env var
    // which should point to a service account JSON on the server.
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
    console.log('✅ firebase-admin initialized');
  }
} catch (err) {
  console.error('❌ firebase-admin init failed', err);
}

// Middleware to check API key
function requireApiKey(req, res, next) {
  const sent = req.get('X-API-KEY') || req.body.apiKey;
  if (!SERVER_API_KEY) {
    return res.status(500).json({ error: 'SERVER_API_KEY not configured on server' });
  }
  if (sent !== SERVER_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// Send FCM via firebase-admin
app.post('/api/send-fcm', requireApiKey, async (req, res) => {
  const { token, title, body, data } = req.body;
  if (!token) return res.status(400).json({ error: 'missing token' });
  const message = {
    token,
    notification: { title, body },
    data: data || {},
  };
  try {
    const result = await admin.messaging().send(message);
    return res.json({ ok: true, result });
  } catch (err) {
    console.error('FCM send error', err);
    return res.status(500).json({ error: err.message || err });
  }
});

// Forward to OneSignal (server-side secret)
app.post('/api/onesignal/notify', requireApiKey, async (req, res) => {
  if (!ONE_SIGNAL_REST_KEY || !ONE_SIGNAL_APP_ID) {
    return res.status(500).json({ error: 'OneSignal keys not configured' });
  }
  const { title, body, playerId, segment, data } = req.body;
  const payload = {
    app_id: ONE_SIGNAL_APP_ID,
    headings: { en: title },
    contents: { en: body },
    ...(playerId ? { include_player_ids: [playerId] } : {}),
    ...(segment ? { included_segments: [segment] } : {}),
    data: data || {},
  };
  try {
    const r = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: { Authorization: `Basic ${ONE_SIGNAL_REST_KEY}` },
    });
    return res.json({ ok: true, data: r.data });
  } catch (err) {
    console.error('OneSignal forward error', err?.response?.data || err.message);
    return res.status(500).json({ error: err?.response?.data || err.message });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Notification server listening on ${port}`));
