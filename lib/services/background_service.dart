import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:telephony/telephony.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';

// PRO CONFIGURATIONS
const int _minDistanceToSaveHistory = 20; // Save route every 20 meters
const int _stopDetectionMinutes = 3; // Detect a Place Visited after 3 mins
const int _historyRetentionDays = 7;
const int _lowBatteryThreshold = 15; // Trigger alert at 15% battery
const double _maxSpeedLimit = 80.0; // Highway speed alert at 80 km/h

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'LIVE TRACKING (DO NOT DISABLE)',
    description:
        'This keeps the GPS alive and prevents Android from killing the app.',
    importance: Importance.low,
  );

  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'zone_alerts',
    'CRITICAL ALERTS',
    description: 'Notifications for Safe Zones, Speed and Low Battery',
    importance: Importance.max,
  );

  const AndroidNotificationChannel emergencyChannel =
      AndroidNotificationChannel(
    'emergency_alerts_v3',
    'EMERGENCY ALERTS',
    description: 'Critical SOS Notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(emergencyChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'FamilyLink Secure',
      initialNotificationContent: 'Continuous tracking is active...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
        autoStart: true, onForeground: onStart, onBackground: onIosBackground),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async => true;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  final Telephony telephony = Telephony.instance;
  final Battery battery = Battery();

  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((event) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((event) => service.setAsBackgroundService());
    service.setAsForegroundService();
  }

  bool hasSentBatteryAlert = false;
  bool hasSentSpeedAlert = false;
  int lastRainAlertDay = 0;

  StreamSubscription<Position>? positionStreamSubscription;
  Position? lastValidPosition;
  DateTime? lastValidTime;

  Position? potentialStopPosition;
  DateTime? potentialStopTime;
  bool isCurrentlyStopped = false;

  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  List<Map<String, dynamic>> cachedSafeZones = [];
  String activeFamilyCode = "";

  FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .listen((snap) {
    if (snap.exists) {
      var data = snap.data() as Map<String, dynamic>;
      String fCode = data['familyCode'] ?? '';
      if (fCode != activeFamilyCode && fCode.isNotEmpty) {
        activeFamilyCode = fCode;
        FirebaseFirestore.instance
            .collection('families')
            .doc(fCode)
            .collection('zones')
            .snapshots()
            .listen((zSnap) {
          cachedSafeZones =
              zSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        });
      }
    }
  });

  // WEATHER ALERT LOGIC
  Timer.periodic(const Duration(hours: 1), (timer) async {
    int currentDay = DateTime.now().day;
    if (lastRainAlertDay == currentDay) return;

    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final response = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current_weather=true'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int weatherCode = data['current_weather']['weathercode'];

        if (weatherCode >= 51 && weatherCode <= 67) {
          _showCustomNotification(plugin, "Weather Alert",
              "Rain expected in your area. Stay safe.");

          if (activeFamilyCode.isNotEmpty) {
            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            String myName = userDoc.exists
                ? (userDoc.data() as Map<String, dynamic>)['name'] ??
                    'Family Member'
                : 'Family Member';
            await FirebaseFirestore.instance
                .collection('families')
                .doc(activeFamilyCode)
                .collection('chat')
                .add({
              'text': 'System Auto-Alert: It is raining in my area.',
              'senderId': user.uid,
              'senderName': "$myName's Device",
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
          lastRainAlertDay = currentDay;
        }
      }
    } catch (e) {}
  });

  // SHAKE TO SOS LOGIC
  int shakeCount = 0;
  DateTime? firstShakeTime;
  bool isSOSAlreadyTriggered = false;

  userAccelerometerEventStream().listen((UserAccelerometerEvent event) async {
    if (isSOSAlreadyTriggered) return;
    double gForce =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (gForce > 35.0) {
      DateTime now = DateTime.now();
      if (firstShakeTime == null ||
          now.difference(firstShakeTime!).inSeconds > 3) {
        shakeCount = 1;
        firstShakeTime = now;
      } else {
        shakeCount++;
        if (shakeCount >= 4) {
          shakeCount = 0;
          isSOSAlreadyTriggered = true;

          _showCustomNotification(
              plugin, "SOS TRIGGERED", "Emergency protocol activated",
              id: 999);

          try {
            Position pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
            String mapLink =
                "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'status': 'SOS ACTIVE',
              'isSOS': true,
              'lat': pos.latitude,
              'lng': pos.longitude,
            });

            var contacts = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('trusted_contacts')
                .get();
            for (var doc in contacts.docs) {
              String? num = doc
                  .data()['phone']
                  ?.toString()
                  .replaceAll(RegExp(r'[^0-9+]'), '');
              if (num != null && num.isNotEmpty) {
                try {
                  telephony.sendSms(
                      to: num,
                      message:
                          "EMERGENCY SOS: I need help. My Location: $mapLink");
                } catch (e) {}
              }
            }

            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            String myName =
                (userDoc.data() as Map<String, dynamic>?)?['name'] ??
                    'Family Member';
            _captureAndSendEmergencyAudio(user.uid, activeFamilyCode, myName);
          } catch (e) {}
          Future.delayed(
              const Duration(minutes: 2), () => isSOSAlreadyTriggered = false);
        }
      }
    }
  });

  // GPS TRACKING LOGIC
  void startGpsTracking() {
    if (positionStreamSubscription != null) return;

    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 15, // PRO FILTER: Only trigger if moved 15 meters
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Tracking your safety securely...",
        notificationTitle: "FamilyLink Live",
        enableWakeLock: true,
      ),
    );

    positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
      try {
        // PRO FILTER: Ignore low accuracy points (Fixes the spiderweb map lines)
        if (position.accuracy > 60.0) return;

        double speedKmh = position.speed * 3.6;

        if (lastValidPosition != null && lastValidTime != null) {
          double distanceMoved = Geolocator.distanceBetween(
              lastValidPosition!.latitude,
              lastValidPosition!.longitude,
              position.latitude,
              position.longitude);
          int timeDiffSeconds =
              position.timestamp.difference(lastValidTime!).inSeconds;

          if (timeDiffSeconds > 0) {
            double calculatedSpeedKmh = (distanceMoved / timeDiffSeconds) * 3.6;
            if (calculatedSpeedKmh > 150.0) {
              speedKmh = 0.0;
            } else {
              speedKmh = calculatedSpeedKmh;
            }
          }
        }

        if (potentialStopPosition == null) {
          potentialStopPosition = position;
          potentialStopTime = DateTime.now();
        } else {
          double distFromStop = Geolocator.distanceBetween(
              potentialStopPosition!.latitude,
              potentialStopPosition!.longitude,
              position.latitude,
              position.longitude);

          if (distFromStop < 30.0) {
            if (!isCurrentlyStopped &&
                DateTime.now().difference(potentialStopTime!).inMinutes >=
                    _stopDetectionMinutes) {
              isCurrentlyStopped = true;
              _saveVisitToInsights(user.uid, position);
            }
          } else {
            potentialStopPosition = position;
            potentialStopTime = DateTime.now();

            if (isCurrentlyStopped) {
              isCurrentlyStopped = false;
              _updateDepartureTime(user.uid);
            }
          }
        }

        lastValidPosition = position;
        lastValidTime = position.timestamp;

        int batteryLevel = 0;
        try {
          batteryLevel = await battery.batteryLevel;
        } catch (e) {
          batteryLevel = 0;
        }

        if (batteryLevel > 0 &&
            batteryLevel <= _lowBatteryThreshold &&
            !hasSentBatteryAlert) {
          hasSentBatteryAlert = true;

          _showCustomNotification(
              plugin, "Battery Critical", "Your battery is at $batteryLevel%",
              id: 9001);

          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            String myName =
                (userDoc.data() as Map<String, dynamic>?)?['name'] ??
                    'Family Member';
            if (activeFamilyCode.isNotEmpty) {
              _sendAlertToFamily(activeFamilyCode, user.uid, myName,
                  "Alert: $myName's phone battery is critically low ($batteryLevel%).");
            }
          }
        } else if (batteryLevel > _lowBatteryThreshold) {
          hasSentBatteryAlert = false;
        }

        plugin.show(
          id: 888,
          title: 'FamilyLink Secure',
          body:
              'Speed: ${speedKmh.toStringAsFixed(0)} km/h | Bat: $batteryLevel%',
          notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails('my_foreground', 'TRACKER',
                  ongoing: true, icon: '@mipmap/ic_launcher')),
        );

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!userDoc.exists) return;

        Map<String, dynamic> userData =
            userDoc.data() as Map<String, dynamic>? ?? {};
        bool isGhostMode = userData['ghostMode'] ?? false;
        String myName = userData['name'] ?? 'Family Member';

        if (isGhostMode) return;

        if (activeFamilyCode.isNotEmpty && cachedSafeZones.isNotEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.reload();

          for (var zone in cachedSafeZones) {
            double zoneLat = (zone['lat'] ?? 0.0).toDouble();
            double zoneLng = (zone['lng'] ?? 0.0).toDouble();
            double zoneRadius = (zone['radius'] ?? 100).toDouble();
            String zoneName = zone['name'] ?? 'Safe Zone';
            String zoneId = zone['id'];

            String prefKey = 'inside_zone_$zoneId';
            bool isInsideThisZone = prefs.getBool(prefKey) ?? false;

            double distanceToZone = Geolocator.distanceBetween(
                position.latitude, position.longitude, zoneLat, zoneLng);
            bool currentlyInside = distanceToZone <= zoneRadius;

            if (currentlyInside && !isInsideThisZone) {
              await prefs.setBool(prefKey, true);
              _showCustomNotification(
                  plugin, "Safe Zone Alert", "You safely arrived at $zoneName",
                  id: zoneId.hashCode);
              _sendAlertToFamily(activeFamilyCode, user.uid, myName,
                  "$myName has safely arrived at $zoneName.");
            } else if (!currentlyInside && isInsideThisZone) {
              await prefs.setBool(prefKey, false);
              _showCustomNotification(
                  plugin, "Safe Zone Alert", "You left $zoneName",
                  id: zoneId.hashCode);
              _sendAlertToFamily(activeFamilyCode, user.uid, myName,
                  "$myName has left $zoneName.");
            }
          }

          if (speedKmh > _maxSpeedLimit && !hasSentSpeedAlert) {
            hasSentSpeedAlert = true;
            _showCustomNotification(plugin, "Speed Warning",
                "Speeding detected: ${speedKmh.toInt()} km/h",
                id: 9002);
            _sendAlertToFamily(activeFamilyCode, user.uid, myName,
                "Alert: $myName is traveling fast at ${speedKmh.toInt()} km/h");
            Future.delayed(
                const Duration(minutes: 5), () => hasSentSpeedAlert = false);
          }
        }

        String status = speedKmh > 20
            ? "Driving"
            : (speedKmh > 2 ? "Walking" : "Stationary");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lat': position.latitude,
          'lng': position.longitude,
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'batteryLevel': batteryLevel,
          'speed': speedKmh,
          'status': status,
          'lastActive': FieldValue.serverTimestamp(),
        });

        _manageLocationHistory(user.uid, position, speedKmh);
      } catch (e) {}
    });
  }

  startGpsTracking();
}

Future<void> _sendAlertToFamily(
    String fCode, String uid, String name, String msg) async {
  await FirebaseFirestore.instance
      .collection('families')
      .doc(fCode)
      .collection('chat')
      .add({
    'senderId': 'system',
    'senderName': 'System AI',
    'text': msg,
    'type': 'system_alert',
    'timestamp': FieldValue.serverTimestamp(),
  });
  var usersSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('familyCode', isEqualTo: fCode)
      .get();
  for (var memberDoc in usersSnapshot.docs) {
    if (memberDoc.id != uid) {
      String? fcmToken = memberDoc.data()['fcmToken'];
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await PushNotificationService.sendPushMessage(
            targetFcmToken: fcmToken, title: "Family Alert", body: msg);
      }
    }
  }
}

Future<void> _saveVisitToInsights(String uid, Position pos) async {
  try {
    String placeName = "Unknown Location";
    List<Placemark> placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks.isNotEmpty) {
      placeName =
          "${placemarks[0].subLocality ?? placemarks[0].street}, ${placemarks[0].locality ?? placemarks[0].administrativeArea}"
              .replaceAll(RegExp(r'^, |, $'), '');
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insights_history')
        .add({
      'placeName': placeName,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'arrivalTime': FieldValue.serverTimestamp(),
      'departureTime': null
    });
  } catch (e) {}
}

Future<void> _updateDepartureTime(String uid) async {
  try {
    var lastVisit = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insights_history')
        .orderBy('arrivalTime', descending: true)
        .limit(1)
        .get();
    if (lastVisit.docs.isNotEmpty &&
        lastVisit.docs.first['departureTime'] == null) {
      await lastVisit.docs.first.reference
          .update({'departureTime': FieldValue.serverTimestamp()});
    }
  } catch (e) {}
}

Future<void> _captureAndSendEmergencyAudio(
    String uid, String familyCode, String myName) async {
  try {
    final AudioRecorder audioRecorder = AudioRecorder();
    if (await audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      String filePath =
          '${dir.path}/bg_sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath);
      await Future.delayed(const Duration(seconds: 10));
      String? finalPath = await audioRecorder.stop();

      if (finalPath != null && familyCode.isNotEmpty) {
        File audioFile = File(finalPath);
        List<int> fileBytes = await audioFile.readAsBytes();
        await FirebaseFirestore.instance
            .collection('families')
            .doc(familyCode)
            .collection('chat')
            .add({
          'senderId': uid,
          'senderName': myName,
          'text': "Auto-captured Surround Audio during SOS alert",
          'audioBase64': base64Encode(fileBytes),
          'type': 'sos_audio',
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (await audioFile.exists()) await audioFile.delete();
      }
    }
  } catch (e) {}
}

void _manageLocationHistory(String uid, Position pos, double speed) async {
  var lastPoint = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('locationHistory')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();
  bool shouldSave = lastPoint.docs.isEmpty;
  if (!shouldSave) {
    double dist = Geolocator.distanceBetween(lastPoint.docs.first['lat'],
        lastPoint.docs.first['lng'], pos.latitude, pos.longitude);
    if (dist >= _minDistanceToSaveHistory) shouldSave = true;
  }
  if (shouldSave) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locationHistory')
        .add({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed': speed,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
  DateTime cutoffRoute =
      DateTime.now().subtract(const Duration(days: _historyRetentionDays));
  var oldRoute = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('locationHistory')
      .where('timestamp', isLessThan: Timestamp.fromDate(cutoffRoute))
      .get();
  for (var d in oldRoute.docs) d.reference.delete();
}

void _showCustomNotification(
    FlutterLocalNotificationsPlugin plugin, String title, String body,
    {int id = 0}) {
  int finalId = id == 0 ? DateTime.now().millisecond : id;

  plugin.show(
      id: finalId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('zone_alerts', 'ALERTS',
              importance: Importance.max, priority: Priority.high)));
}
