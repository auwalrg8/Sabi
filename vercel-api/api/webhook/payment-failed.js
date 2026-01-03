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
    const { nostrPubkey, amountSats, amountNaira, errorMessage, recipientName } = req.body;

    if (!nostrPubkey || !amountSats) {
      return res.status(400).json({ error: 'nostrPubkey and amountSats are required' });
    }

    let body = `Failed to send ${Number(amountSats).toLocaleString()} sats`;
    if (amountNaira) {
      body += ` (₦${amountNaira})`;
    }
    if (recipientName) {
      body += ` to ${recipientName}`;
    }
    if (errorMessage) {
      // Truncate error message if too long
      const truncatedError = errorMessage.length > 100 
        ? errorMessage.substring(0, 100) + '...' 
        : errorMessage;
      body += `\nError: ${truncatedError}`;
    }

    const result = await sendPushToUser(nostrPubkey, {
      title: '❌ Payment Failed',
      body,
      data: {
        type: 'payment-failed',
        amountSats: String(amountSats),
        errorMessage: errorMessage || '',
      },
    });

    console.log(`Payment failed notification sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending payment failed notification:', error);
    return res.status(500).json({ error: 'Internal server error', details: error.message });
  }
}
