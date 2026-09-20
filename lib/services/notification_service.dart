import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Color;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  // ── Show message notification ─────────────────────────────────────────
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String peerId,
  }) async {
    final displayMessage = message.startsWith('LOCATION|')
        ? '📍 Shared their location with you'
        : message;

    await _plugin.show(
      peerId.hashCode,
      senderName,
      displayMessage,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dm_channel',
          'Direct Messages',
          channelDescription: 'Private messages from friends',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF00FF88),
        ),
      ),
    );
  }

  // ── Show friend request notification ─────────────────────────────────
  Future<void> showFriendRequestNotification({
    required String senderName,
  }) async {
    await _plugin.show(
      senderName.hashCode,
      'Friend Request',
      '$senderName wants to connect with you',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'friend_request_channel',
          'Friend Requests',
          channelDescription: 'Incoming friend requests',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF00FF88),
        ),
      ),
    );
  }
}