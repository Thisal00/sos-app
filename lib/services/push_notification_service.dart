import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PushNotificationService {
  // Retrieve Google Access Token for FCM v1 Authorization
  static Future<String> _getAccessToken() async {
    try {
      // Load service account key from assets
      final jsonString =
          await rootBundle.loadString('assets/service_account.json');
      final accountCredentials =
          auth.ServiceAccountCredentials.fromJson(jsonString);

      // Define the scope required for Firebase Cloud Messaging
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Generate the OAuth2 client and extract the access token
      final client =
          await auth.clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();

      return accessToken;
    } catch (e) {
      debugPrint("[PushNotificationService] Access Token Error: $e");
      return "";
    }
  }

  // Send Push Notification via Firebase Cloud Messaging v1 API
  static Future<void> sendPushMessage({
    required String targetFcmToken,
    required String title,
    required String body,
  }) async {
    try {
      // Load service account JSON to extract the Project ID dynamically
      final jsonString =
          await rootBundle.loadString('assets/service_account.json');
      final jsonData = jsonDecode(jsonString);
      final projectId = jsonData['project_id'];

      // Generate the authorized access token
      final String serverToken = await _getAccessToken();
      if (serverToken.isEmpty) {
        debugPrint(
            "[PushNotificationService] Failed to get access token. Notification aborted.");
        return;
      }

      // Define the Google FCM v1 API Endpoint
      final String endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      // Construct the message payload
      final Map<String, dynamic> message = {
        'message': {
          'token': targetFcmToken, // Target device FCM token
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'click_action':
                'FLUTTER_NOTIFICATION_CLICK', // Action to open the app on click
            'status': 'done',
          }
        }
      };

      // Execute the HTTP POST request to Google FCM
      final response = await http.post(
        Uri.parse(endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serverToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint(
            "[PushNotificationService] Push Notification Sent Successfully to $targetFcmToken");
      } else {
        debugPrint(
            "[PushNotificationService] Push Notification Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint(
          "[PushNotificationService] Error sending push notification: $e");
    }
  }
}
