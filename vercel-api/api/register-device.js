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
    const { fcmToken, nostrPubkey, platform, appVersion } = req.body;

    if (!fcmToken || !nostrPubkey) {
      return res.status(400).json({ error: 'fcmToken and nostrPubkey are required' });
    }

    if (!db) {
      console.log('Firebase not configured - skipping device registration');
      return res.status(200).json({ success: true, message: 'Firebase not configured' });
    }

    // Store device info
    const deviceRef = db.collection('devices').doc(fcmToken);
    await deviceRef.set({
      fcmToken,
      nostrPubkey,
      platform: platform || 'unknown',
      appVersion: appVersion || 'unknown',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }, { merge: true });

    // Add token to pubkey's token list
    const pubkeyRef = db.collection('pubkey_devices').doc(nostrPubkey);
    const pubkeyDoc = await pubkeyRef.get();
    
    if (pubkeyDoc.exists) {
      const existingTokens = pubkeyDoc.data()?.tokens || [];
      if (!existingTokens.includes(fcmToken)) {
        await pubkeyRef.update({
          tokens: [...existingTokens, fcmToken],
          updatedAt: new Date().toISOString(),
        });
      }
    } else {
      await pubkeyRef.set({
        tokens: [fcmToken],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    }

    console.log(`✅ Registered device for pubkey: ${nostrPubkey.substring(0, 8)}...`);
    return res.status(200).json({ success: true });

  } catch (error) {
    console.error('Error registering device:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
