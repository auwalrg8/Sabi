import { sendPushToUser } from '../../lib/firebase.js';

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
    const { nostrPubkey, senderName, senderPubkey, preview } = req.body;

    if (!nostrPubkey) {
      return res.status(400).json({ error: 'nostrPubkey is required' });
    }

    const title = senderName ? `💬 ${senderName}` : '💬 New Message';
    const body = preview || 'You have a new encrypted message';

    const result = await sendPushToUser(nostrPubkey, {
      title,
      body,
      data: {
        type: 'dm',
        senderPubkey: senderPubkey || '',
      },
    });

    console.log(`DM notification sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending DM notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
