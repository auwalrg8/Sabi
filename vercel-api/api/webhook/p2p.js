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
    const { nostrPubkey, tradeId, eventType, amount, counterpartyName } = req.body;

    if (!nostrPubkey || !tradeId || !eventType) {
      return res.status(400).json({ error: 'nostrPubkey, tradeId, and eventType are required' });
    }

    const notifications = {
      trade_started: {
        title: '🔄 New Trade Started',
        body: counterpartyName 
          ? `${counterpartyName} started a trade with you${amount ? ` for ${amount}` : ''}`
          : `A new trade has started${amount ? ` for ${amount}` : ''}`,
      },
      payment_marked: {
        title: '💰 Payment Marked',
        body: `Buyer has marked payment as sent${amount ? ` for ${amount}` : ''}. Please verify.`,
      },
      payment_confirmed: {
        title: '✅ Payment Confirmed',
        body: 'Seller has confirmed receiving your payment.',
      },
      funds_released: {
        title: '🎉 Trade Complete!',
        body: `Funds have been released${amount ? `. You received ${amount}` : ''}`,
      },
      trade_cancelled: {
        title: '❌ Trade Cancelled',
        body: 'The trade has been cancelled.',
      },
      trade_disputed: {
        title: '⚠️ Trade Disputed',
        body: 'A dispute has been opened on this trade.',
      },
      new_message: {
        title: '💬 New Message',
        body: counterpartyName
          ? `${counterpartyName} sent you a message`
          : 'You have a new message in your trade',
      },
      new_inquiry: {
        title: '📩 New Inquiry',
        body: counterpartyName
          ? `${counterpartyName} is interested in your offer`
          : 'Someone is interested in your offer',
      },
    };

    const notification = notifications[eventType] || {
      title: '🔔 P2P Update',
      body: `Trade update: ${eventType}`,
    };

    const result = await sendPushToUser(nostrPubkey, {
      title: notification.title,
      body: notification.body,
      data: {
        type: 'p2p',
        eventType,
        tradeId,
      },
    });

    console.log(`P2P notification (${eventType}) sent: ${result.sent} success`);
    return res.status(200).json(result);

  } catch (error) {
    console.error('Error sending P2P notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
