const express = require('express');
const cors = require('cors');

// fetch を node-fetch 経由で定義（ESM互換）
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

const DFP_ENDPOINT = 'https://www.mlit-data.jp/api/v1/graphql';
const API_KEY = '4ZiwH4ty7rcYPfye2sYP9DjX9BBjCOzY';

app.post('/dfp', async (req, res) => {
  try {
    console.log('▶ GraphQL Query:', JSON.stringify(req.body, null, 2));

    const response = await fetch(DFP_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': API_KEY
      },
      body: JSON.stringify(req.body)
    });

    const text = await response.text();
    console.log('▶ DFP Response:', text);
    res.type('application/json').send(text);
  } catch (err) {
    console.error('❌ DFP API error:', err);
    res.status(500).json({ error: 'DFP API proxy failed' });
  }
});

app.listen(PORT, () => {
  console.log(`✅ DFP proxy server running at http://localhost:${PORT}`);
});