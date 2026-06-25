/**
 * Firebase Admin SDK initialization for push notifications
 */
const admin = require('firebase-admin');

// Initialize Firebase Admin with service account
// The service account JSON should be stored in an environment variable
function initFirebase() {
  try {
    // Check if already initialized
    if (admin.apps.length > 0) {
      return admin;
    }

    // Check for service account credentials
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
    
    if (!serviceAccountJson) {
      console.warn('⚠️  FIREBASE_SERVICE_ACCOUNT not set. Push notifications disabled.');
      console.warn('   To enable: Create a service account in Firebase Console → Project Settings → Service Accounts');
      return null;
    }

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (e) {
      console.error('❌ Invalid FIREBASE_SERVICE_ACCOUNT JSON:', e.message);
      return null;
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log('✅ Firebase Admin initialized');
    return admin;
  } catch (error) {
    console.error('❌ Firebase Admin initialization failed:', error);
    return null;
  }
}

/**
 * Send push notification to a specific user
 * @param {string} fcmToken - User's FCM token
 * @param {Object} payload - Notification payload
 * @param {string} payload.title - Notification title
 * @param {string} payload.body - Notification body
 * @param {Object} payload.data - Additional data payload
 */
async function sendPushNotification(fcmToken, payload) {
  const firebase = initFirebase();
  if (!firebase) {
    console.log('📭 Push notification skipped (Firebase not configured)');
    return;
  }

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      android: {
        notification: {
          channelId: 'new_messages',
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await firebase.messaging().send(message);
    console.log(`📱 Push sent: ${response}`);
    return response;
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered') {
      console.warn('⚠️  FCM token expired or invalid');
      // Token should be removed from user's record
      throw new Error('INVALID_TOKEN');
    }
    console.error('❌ Push notification failed:', error);
    throw error;
  }
}

/**
 * Send push notification to multiple users
 * @param {string[]} fcmTokens - Array of FCM tokens
 * @param {Object} payload - Notification payload
 */
async function sendMulticastPush(fcmTokens, payload) {
  const firebase = initFirebase();
  if (!firebase || fcmTokens.length === 0) {
    return;
  }

  try {
    const message = {
      tokens: fcmTokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
    };

    const response = await firebase.messaging().sendEachForMulticast(message);
    console.log(`📱 Multicast push: ${response.successCount} success, ${response.failureCount} failed`);
    
    // Clean up invalid tokens
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        if (resp.error?.code === 'messaging/registration-token-not-registered') {
          invalidTokens.push(fcmTokens[idx]);
        }
      }
    });
    
    return { response, invalidTokens };
  } catch (error) {
    console.error('❌ Multicast push failed:', error);
    throw error;
  }
}

module.exports = {
  initFirebase,
  sendPushNotification,
  sendMulticastPush,
};
