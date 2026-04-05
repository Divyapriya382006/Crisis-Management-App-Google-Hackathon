import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'crisis_alerts';
  static const _channelName = 'Crisis Alerts';

  Future<void> init() async {
    // Skip notifications on web/unsupported
    if (kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
        
    debugPrint('Notification Service Initialized (Local Only)');
  }

  void showLocalNotification({required String title, required String body}) {
    _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFFFF3B30),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}