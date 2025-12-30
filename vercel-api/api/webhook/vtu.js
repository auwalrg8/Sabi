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
    const { nostrPubkey, orderId, orderType, status, amount, phoneNumber } = req.body;

    if (!nostrPubkey || !orderId || !orderType || !status) {
      return res.status(400).json({ 
        error: 'nostrPubkey, orderId, orderType, and status are required' 
      });
    }

    const typeLabels = {
      airtime: 'Airtime',
      data: 'Data',
      electricity: 'Electricity',
    };

    const typeLabel = typeLabels[orderType] || orderType;
    const isSuccess = status === 'complete';

    let body;
    if (isSuccess) {
      body = `Your ${typeLabel} purchase${amount ? ` of ${amount}` : ''} was successful`;
      if (phoneNumber) {
        body += ` for ${phoneNumber}`;
      }
    } else {
      body = `Your ${typeLabel} purchase failed. Please try again.`;
    }

    const result = await sendPushToUser(nostrPubkey, {
      title: isSuccess ? `✅ ${typeLabel} Successful` : `❌ ${typeLabel} Failed`,
      body,
      data: {
        type: 'vtu',
        orderId,
        orderType,
        status,
      },
    });

    console.log(`VTU notification (${status}) sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending VTU notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
