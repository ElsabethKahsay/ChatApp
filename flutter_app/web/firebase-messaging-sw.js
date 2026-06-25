importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAmi9watS1x3lrQLt3l0x6r2K2-8AXt4WQ',
  appId: '1:251505035498:web:12a10beef3c3e0b53daf93',
  messagingSenderId: '251505035498',
  projectId: 'chatapp-b46ea',
  authDomain: 'chatapp-b46ea.firebaseapp.com',
  storageBucket: 'chatapp-b46ea.firebasestorage.app',
  measurementId: 'G-TMF6K5V6CC',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/favicon.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
