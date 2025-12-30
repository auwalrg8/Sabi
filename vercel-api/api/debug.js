import { db, messaging } from '../lib/firebase.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');

  const status = {
    firebase: {
      projectId: process.env.FIREBASE_PROJECT_ID ? 'set' : 'missing',
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL ? 'set' : 'missing',
      privateKey: process.env.FIREBASE_PRIVATE_KEY ? 'set (length: ' + process.env.FIREBASE_PRIVATE_KEY.length + ')' : 'missing',
      dbInitialized: db ? true : false,
      messagingInitialized: messaging ? true : false,
    },
    timestamp: new Date().toISOString(),
  };

  // Try a simple Firestore operation
  if (db) {
    try {
      const testRef = db.collection('_health').doc('check');
      await testRef.set({ lastCheck: new Date().toISOString() });
      status.firestore = 'connected';
    } catch (error) {
      status.firestore = 'error: ' + error.message;
    }
  }

  return res.status(200).json(status);
}
