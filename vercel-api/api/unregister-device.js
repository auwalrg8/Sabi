import { db } from '../lib/firebase.js';

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
    const { fcmToken, nostrPubkey } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }

    if (!db) {
      return res.status(200).json({ success: true, message: 'Firebase not configured' });
    }

    // Delete device document
    await db.collection('devices').doc(fcmToken).delete();

    // Remove token from pubkey's token list
    if (nostrPubkey) {
      const pubkeyRef = db.collection('pubkey_devices').doc(nostrPubkey);
      const pubkeyDoc = await pubkeyRef.get();
      
      if (pubkeyDoc.exists) {
        const existingTokens = pubkeyDoc.data()?.tokens || [];
        const updatedTokens = existingTokens.filter(t => t !== fcmToken);
        
        if (updatedTokens.length > 0) {
          await pubkeyRef.update({
            tokens: updatedTokens,
            updatedAt: new Date().toISOString(),
          });
        } else {
          await pubkeyRef.delete();
        }
      }
    }

    console.log(`✅ Unregistered device token`);
    return res.status(200).json({ success: true });

  } catch (error) {
    console.error('Error unregistering device:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
