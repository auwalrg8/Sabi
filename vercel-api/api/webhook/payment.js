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
    const { nostrPubkey, amountSats, amountNaira, paymentHash, description } = req.body;

    if (!nostrPubkey || !amountSats) {
      return res.status(400).json({ error: 'nostrPubkey and amountSats are required' });
    }

    let body = `You received ${amountSats.toLocaleString()} sats`;
    if (amountNaira) {
      body += ` (₦${amountNaira})`;
    }
    if (description) {
      body += `\n${description}`;
    }

    const result = await sendPushToUser(nostrPubkey, {
      title: '⚡ Payment Received!',
      body,
      data: {
        type: 'payment',
        amountSats: String(amountSats),
        paymentHash: paymentHash || '',
      },
    });

    console.log(`Payment notification sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending payment notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
