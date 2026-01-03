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
    const { nostrPubkey, amountSats, senderName, message, eventId } = req.body;

    if (!nostrPubkey || !amountSats) {
      return res.status(400).json({ error: 'nostrPubkey and amountSats are required' });
    }

    let body = senderName
      ? `${senderName} zapped you ${amountSats.toLocaleString()} sats`
      : `You received a ${amountSats.toLocaleString()} sat zap`;
    
    if (message) {
      body += `\n"${message}"`;
    }

    const result = await sendPushToUser(nostrPubkey, {
      title: '⚡ Zap Received!',
      body,
      data: {
        type: 'zap',
        amountSats: String(amountSats),
        eventId: eventId || '',
      },
    });

    console.log(`Zap notification sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending zap notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
