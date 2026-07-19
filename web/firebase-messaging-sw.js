// Firebase Cloud Messaging service worker for background push notifications.
// Runs in a separate thread so notifications are delivered even when the
// browser tab is inactive or closed.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBOKLqam_2qy-BQDLQLWrUwN6N7_YfWHr0',
  appId: '1:508579954527:web:143fed6487138a884300ea',
  messagingSenderId: '508579954527',
  projectId: 'society-e1a2e',
  authDomain: 'society-e1a2e.firebaseapp.com',
  storageBucket: 'society-e1a2e.firebasestorage.app',
  measurementId: 'G-FL8MHBKD41',
});

// Derive base path from the service worker location so icon URLs resolve
// correctly even when the app is deployed under a non-root --base-href.
var basePath = self.location.pathname.replace('firebase-messaging-sw.js', '');
var iconUrl = basePath + 'icons/Icon-192.png';

var messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  var notification = payload.notification;
  if (!notification) return;

  var title = notification.title || 'GatePass+';
  var options = {
    body: notification.body || '',
    icon: iconUrl,
    badge: iconUrl,
    data: payload.data || {},
  };

  return self.registration.showNotification(title, options);
});
