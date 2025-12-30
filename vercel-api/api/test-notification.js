import { sendPushToUser } from '../lib/firebase.js';

export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { nostrPubkey, title, body, type } = req.body;

    if (!nostrPubkey) {
      return res.status(400).json({ error: 'nostrPubkey is required' });
    }

    const result = await sendPushToUser(nostrPubkey, {
      title: title || '🔔 Test Notification',
      body: body || 'Push notifications are working! 🎉',
      data: {
        type: type || 'test',
        timestamp: new Date().toISOString(),
      },
    });

    console.log(`Test notification sent to ${nostrPubkey.substring(0, 8)}...: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending test notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
