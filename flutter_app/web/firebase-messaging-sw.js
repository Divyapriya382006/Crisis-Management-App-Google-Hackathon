importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAOFGlxVvdhx0W6WEpwBEobZep5pldsY40",
  authDomain: "crisis-responder.firebaseapp.com",
  projectId: "crisis-responder",
  storageBucket: "crisis-responder.firebasestorage.app",
  messagingSenderId: "1008177715054",
  appId: "1:1008177715054:web:5faea23bd3ef1c6d77937f",
  measurementId: "G-6RFN9P6R9G"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification;
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});