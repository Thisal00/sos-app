import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Background Handler for Direct Replies
@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'REPLY_ACTION') {
    final String? replyText = notificationResponse.input;
    final String? payload = notificationResponse.payload;

    if (replyText != null && replyText.isNotEmpty && payload != null) {
      try {
        List<String> data = payload.split('|');
        if (data.length == 3) {
          String familyCode = data[0];
          String uid = data[1];
          String userName = data[2];

          // Initialize Firebase in the isolated background process
          await Firebase.initializeApp();

          // Write direct reply to Firestore
          await FirebaseFirestore.instance
              .collection('families')
              .doc(familyCode)
              .collection('chat')
              .add({
            'text': replyText.trim(),
            'senderId': uid,
            'senderName': userName,
            'type': 'text',
            'timestamp': FieldValue.serverTimestamp(),
          });

          debugPrint("Background reply executed successfully.");
        }
      } catch (e) {
        debugPrint("Background reply execution failed: $e");
      }
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize the notification service
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // FIXED: Added the 'settings:' named argument required by your package version
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // General High-Priority Alerts (SOS, Geofence Triggers, Weather)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'critical_alerts_channel',
      'Security & Emergency Alerts',
      channelDescription: 'High priority alerts for SOS and Safe Zone breaches',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      color: Colors.redAccent,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    // FIXED: Added 'id:', 'title:', 'body:', and 'notificationDetails:' named arguments
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  // Interactive Chat Notification with Direct Reply
  static Future<void> showChatNotification({
    required int id,
    required String title,
    required String body,
    required String familyCode,
    required String uid,
    required String userName,
  }) async {
    // Configure the inline reply action
    const AndroidNotificationAction replyAction = AndroidNotificationAction(
      'REPLY_ACTION',
      'Reply',
      icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      inputs: <AndroidNotificationActionInput>[
        AndroidNotificationActionInput(
          label: 'Type your message...',
        ),
      ],
      showsUserInterface: false,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'family_chat_channel',
      'Family Communications',
      channelDescription: 'Real-time Family Chat Messages',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.indigo,
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[replyAction],
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // FIXED: Added all required named arguments here as well
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: '$familyCode|$uid|$userName',
    );
  }
}
