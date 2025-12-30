import admin from 'firebase-admin';

// Initialize Firebase Admin SDK once
if (!admin.apps.length) {
  // Trim environment variables to remove any Windows line endings (\r\n)
  const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.trim()?.replace(/\\n/g, '\n');
  
  if (projectId && clientEmail && privateKey) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }
}

export const db = admin.apps.length ? admin.firestore() : null;
export const messaging = admin.apps.length ? admin.messaging() : null;

/**
 * Get all FCM tokens for a Nostr pubkey
 */
export async function getTokensForPubkey(nostrPubkey) {
  if (!db) return [];
  
  try {
    const docRef = db.collection('pubkey_devices').doc(nostrPubkey);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return [];
    }
    
    const data = doc.data();
    return data?.tokens || [];
  } catch (error) {
    console.error('Error getting tokens for pubkey:', error);
    return [];
  }
}

/**
 * Send push notification to a user by their Nostr pubkey
 */
export async function sendPushToUser(nostrPubkey, notification) {
  if (!messaging || !db) {
    console.log('Firebase not initialized - missing credentials');
    return { success: false, sent: 0, failed: 0, error: 'Firebase not configured' };
  }

  const tokens = await getTokensForPubkey(nostrPubkey);
  
  if (tokens.length === 0) {
    console.log(`No tokens found for pubkey: ${nostrPubkey.substring(0, 8)}...`);
    return { success: false, sent: 0, failed: 0 };
  }

  let sent = 0;
  let failed = 0;
  const invalidTokens = [];

  for (const token of tokens) {
    try {
      await messaging.send({
        token,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        android: {
          priority: 'high',
          notification: {
            channelId: 'sabi_wallet_default',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: notification.title,
                body: notification.body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      sent++;
    } catch (error) {
      failed++;
      if (
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(token);
      }
      console.error(`Failed to send to token: ${error.message}`);
    }
  }

  // Clean up invalid tokens
  if (invalidTokens.length > 0 && db) {
    try {
      const docRef = db.collection('pubkey_devices').doc(nostrPubkey);
      const validTokens = tokens.filter(t => !invalidTokens.includes(t));
      await docRef.update({ tokens: validTokens });
      console.log(`Cleaned up ${invalidTokens.length} invalid tokens`);
    } catch (e) {
      console.error('Error cleaning up tokens:', e);
    }
  }

  return { success: sent > 0, sent, failed };
}
