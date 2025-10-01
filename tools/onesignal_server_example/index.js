const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
app.use(bodyParser.json());

// Load ONE_SIGNAL_REST_KEY and APP_ID from environment variables
const ONE_SIGNAL_REST_KEY = process.env.ONE_SIGNAL_REST_KEY;
const ONE_SIGNAL_APP_ID = process.env.ONE_SIGNAL_APP_ID;

if (!ONE_SIGNAL_REST_KEY || !ONE_SIGNAL_APP_ID) {
  console.warn('ONE_SIGNAL_REST_KEY and ONE_SIGNAL_APP_ID must be set in env');
}

app.post('/api/notify', async (req, res) => {
  try {
    const { title, body, playerId, segment, data } = req.body;

    if (!ONE_SIGNAL_REST_KEY || !ONE_SIGNAL_APP_ID) {
      return res.status(500).json({ error: 'Server not configured with OneSignal keys' });
    }

    const payload = {
      app_id: ONE_SIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: body },
      data: data || {},
    };

    if (playerId) {
      payload.include_player_ids = [playerId];
    } else if (segment) {
      payload.included_segments = [segment];
    } else {
      payload.included_segments = ['All'];
    }

    const response = await axios.post('https://onesignal.com/api/v1/notifications', payload, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${ONE_SIGNAL_REST_KEY}`,
      },
    });

    return res.status(response.status).json(response.data);
  } catch (err) {
    console.error('Error forwarding to OneSignal', err?.response?.data || err.message || err);
    return res.status(500).json({ error: 'Failed to forward to OneSignal' });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`OneSignal forwarding server listening on ${port}`);
});
