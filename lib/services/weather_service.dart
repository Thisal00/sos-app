import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

// Import notification service for sending weather alerts
import 'package:sos/services/notification_service.dart';

class WeatherService {
  static const String _apiKey = "3a019cf61edc12dfef13102b2adce21d";

  static Future<void> checkAndSendMorningAlert({bool isTesting = false}) async {
    DateTime now = DateTime.now();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // අලුත්ම දත්ත ගන්නවා

    String lastSentDate = prefs.getString('last_weather_alert_date') ?? "";
    String todayDate = DateFormat('yyyy-MM-dd').format(now);

    // 🔥 THE FIX: වෙලාව උදේ 6 ඉඳන් දවල් 11 වෙනකන් වැඩි කළා
    if (!isTesting) {
      if (now.hour < 6 || now.hour > 11) {
        debugPrint("[Weather] Not morning window (6AM-11AM). Skipping.");
        return;
      }
      if (lastSentDate == todayDate) {
        debugPrint("[Weather] Already sent today. Skipping.");
        return;
      }
    }

    debugPrint("[WeatherService] Initiating Smart Morning Alert...");
    bool success = await _fetchWeatherAndEventsAndNotify();

    if (success && !isTesting) {
      await prefs.setString('last_weather_alert_date', todayDate);
    }
  }

  static Future<bool> _fetchWeatherAndEventsAndNotify() async {
    try {
      // 🔥 THE FIX: Firebase Null වෙන නිසා Background එකේදි SharedPreferences වලින් ගන්නවා
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentUid = prefs.getString('current_uid') ??
          FirebaseAuth.instance.currentUser?.uid;
      String familyCode = prefs.getString('family_code') ?? "";

      if (currentUid == null) {
        debugPrint("[Weather] User not found. Cancelling.");
        return false;
      }

      int eventCount = 0;

      // Family Code එක නැත්නම් විතරක් ආයෙත් Firebase එකෙන් චෙක් කරනවා
      if (familyCode.isEmpty) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        if (userDoc.exists) {
          familyCode = userDoc.data()?['familyCode'] ?? '';
        }
      }

      if (familyCode.isNotEmpty) {
        String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        var eventsSnap = await FirebaseFirestore.instance
            .collection('families')
            .doc(familyCode)
            .collection('events')
            .where('date', isEqualTo: todayStr)
            .get();
        eventCount = eventsSnap.docs.length;
      }

      // Get GPS location with timeout
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        debugPrint("[Weather] Location Error: $e");
      }

      double lat = 6.9271; // Default: Colombo Latitude
      double lon = 79.8612; // Default: Colombo Longitude
      bool usingDefaultLocation = false;

      // Location එක ගන්න බැරි වුණොත් Default Location එක (Colombo) පාවිච්චි කරනවා
      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
      } else {
        usingDefaultLocation = true;
        debugPrint("[Weather] Using Default Location (Colombo) for Weather.");
      }

      // Fetch weather data from OpenWeather API
      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        double temp = (data['main']['temp'] as num).toDouble();
        String condition = data['weather'][0]['main'].toString().toLowerCase();

        // Location එක ගන්න බැරි වුණා නම් විතරක් නගරයේ නම පෙන්නමු
        String cityName = usingDefaultLocation ? " in ${data['name']}" : "";

        String title = "☀️ Good Morning!";
        String body = "Have a safe day out there.";

        // Smart advice logic with Premium Emojis
        if (condition.contains('rain') ||
            condition.contains('drizzle') ||
            condition.contains('thunderstorm')) {
          title = "🌧️ It's Rainy Today!";
          body = eventCount > 0
              ? "You have $eventCount events today. Take your umbrella!"
              : "It's going to rain today$cityName. Don't forget your umbrella!";
        } else if (temp > 32.0) {
          title = "🔥 Stay Hydrated!";
          body = eventCount > 0
              ? "Busy day with $eventCount events! It's hot (${temp.toInt()}°C), drink plenty of water."
              : "It's a hot day (${temp.toInt()}°C)$cityName. Carry a water bottle!";
        } else if (temp < 24.0) {
          title = "❄️ A bit chilly today";
          body =
              "It's ${temp.toInt()}°C outside$cityName. You might need a light jacket!";
        } else if (eventCount > 0) {
          title = "📅 You have $eventCount Events";
          body =
              "The weather is perfect (${temp.toInt()}°C) for your plans today. Good luck!";
        } else {
          title = "✨ Beautiful Day!";
          body =
              "The weather is clear and it's ${temp.toInt()}°C$cityName. Have a wonderful day!";
        }

        // Send local push notification
        await NotificationService.showNotification(
            id: 999, title: title, body: body);

        // Save alert to bell icon in app
        if (familyCode.isNotEmpty) {
          await _saveAlertToBellIcon(familyCode, title, body);
        }

        debugPrint("[Weather] Smart Alert Sent Successfully!");
        return true;
      }
    } catch (e) {
      debugPrint("[Weather] Fatal Error: $e");
    }
    return false;
  }

  static Future<void> _saveAlertToBellIcon(
      String familyCode, String title, String message) async {
    try {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyCode)
          .collection('alerts')
          .add({
        'type': 'weather',
        'name': 'System AI',
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'uid': 'system_weather',
      });
    } catch (e) {
      debugPrint("[Weather] DB Save Error: $e");
    }
  }
}
