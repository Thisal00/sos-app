import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  // Smart Optimization
  static const double _mergeRadiusForTimeline = 150.0;
  static const int _historyRetentionDays = 5;

  // MANUAL UPDATE (For foreground button presses)
  Future<void> updateMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15));

      // PRO FILTER: Ignore low accuracy points even in manual updates
      if (pos.accuracy > 80.0) {
        debugPrint(
            "[LocationService] Manual Update Ignored: Poor Accuracy (${pos.accuracy}m)");
        return;
      }

      await _processLocationUpdate(pos);
    } catch (e) {
      debugPrint("[LocationService] Manual Update Failed: $e");
    }
  }

  // MAIN FIREBASE SYNC LOGIC
  Future<void> _processLocationUpdate(Position pos) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    String? currentUid = prefs.getString('current_uid') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      debugPrint("[LocationService] User ID not found. Sync canceled.");
      return;
    }

    try {
      var userDoc = await _firestore.collection('users').doc(currentUid).get();
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data()!;
      bool isGhostMode = userData['isGhostMode'] ?? false;
      String familyCode = userData['familyCode'] ?? '';
      String myName = userData['name'] ?? 'Family Member';

      if (isGhostMode) {
        debugPrint("Ghost Mode Active. Tracking paused.");
        return;
      }

      int batteryLevel = 0;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (e) {
        batteryLevel = 0;
      }

      double speedKmh = pos.speed * 3.6;
      String status =
          speedKmh > 20 ? "Driving" : (speedKmh > 2 ? "Walking" : "Stationary");

      String realPlaceName =
          await _getPlaceNameSafely(pos.latitude, pos.longitude);

      Map<String, dynamic> updateData = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'currentLocation': GeoPoint(pos.latitude, pos.longitude),
        'speed': speedKmh,
        'status': status,
        'currentPlace': realPlaceName,
        'lastActive': FieldValue.serverTimestamp(),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'batteryLevel': batteryLevel,
        'isOnline': true,
      };

      await _firestore.collection('users').doc(currentUid).update(updateData);

      if (batteryLevel <= 15 && batteryLevel > 0) {
        await _checkAndSendBatteryAlert(familyCode, myName, batteryLevel);
      }

      // NOTE: Map History saving (_saveForMapHistory) was removed from here because
      // the background_service.dart is already handling it aggressively.

      await _saveForTimelineInsights(
          currentUid, pos, speedKmh, familyCode, myName, realPlaceName);
      _cleanupOldHistory(currentUid);

      debugPrint("[LocationService] Manual Sync Success: $realPlaceName");
    } catch (e) {
      debugPrint("[LocationService] Sync Error: $e");
    }
  }

  // --- Smart Timeline Logic ---
  Future<void> _saveForTimelineInsights(String uid, Position pos, double speed,
      String familyCode, String userName, String realPlaceName) async {
    // Prevent saving useless "Moving..." data into the timeline
    if (realPlaceName == "Moving...") return;

    var lastVisit = await _firestore
        .collection('users')
        .doc(uid)
        .collection('insights_history')
        .orderBy('arrivalTime', descending: true)
        .limit(1)
        .get();

    bool createNewPlace = true;

    if (lastVisit.docs.isNotEmpty) {
      var lastData = lastVisit.docs.first.data();
      double dist = Geolocator.distanceBetween(
          lastData['latitude'] ?? lastData['lat'] ?? 0.0,
          lastData['longitude'] ?? lastData['lng'] ?? 0.0,
          pos.latitude,
          pos.longitude);

      if (dist < _mergeRadiusForTimeline) {
        await lastVisit.docs.first.reference.update({
          'departureTime': FieldValue.serverTimestamp(),
          'placeName': realPlaceName,
        });
        createNewPlace = false;
      }
    }

    if (createNewPlace) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('insights_history')
          .add({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'latitude': pos.latitude, // Kept for backward compatibility
        'longitude': pos.longitude, // Kept for backward compatibility
        'speed': speed,
        'placeName': realPlaceName,
        'arrivalTime': FieldValue.serverTimestamp(),
        'departureTime': FieldValue.serverTimestamp(),
      });

      await _checkAndSendPlaceAlert(familyCode, userName, realPlaceName);
    }
  }

  // --- Alerts Engine ---
  Future<void> _checkAndSendBatteryAlert(
      String familyCode, String userName, int level) async {
    if (familyCode.isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('last_bat_alert') != today) {
      await _sendSystemMessage(familyCode,
          "Warning: $userName's battery is critically low ($level%).");
      await prefs.setString('last_bat_alert', today);
    }
  }

  Future<void> _checkAndSendPlaceAlert(
      String familyCode, String userName, String place) async {
    if (familyCode.isEmpty ||
        place == "Pinned Location" ||
        place == "Moving...") return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString('last_place_alert') != place) {
      await _sendSystemMessage(familyCode, "$userName has arrived at $place.");
      await prefs.setString('last_place_alert', place);
    }
  }

  Future<void> _sendSystemMessage(String familyCode, String msg) async {
    if (familyCode.isEmpty) return;

    await _firestore
        .collection('families')
        .doc(familyCode)
        .collection('chat') // SYNCED: Uses the same path as background_service
        .add({
      'senderId': 'system',
      'senderName': 'System AI',
      'text': msg,
      'type': 'system_alert',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Reverse Geocoding (Address Resolution)
  Future<String> _getPlaceNameSafely(double lat, double lng) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 5));
      if (p.isNotEmpty) {
        String street = p.first.street ?? '';
        String locality = p.first.locality ?? '';

        // Filter out Google Maps Plus Codes
        if (street.contains('+') || street.contains('Unnamed')) {
          return locality.isNotEmpty ? locality : "Pinned Location";
        }

        if (street.isNotEmpty && locality.isNotEmpty) {
          return "$street, $locality".replaceAll(RegExp(r'^, |, $'), '');
        } else if (street.isNotEmpty) {
          return street;
        } else {
          return locality.isNotEmpty ? locality : "Pinned Location";
        }
      }
    } catch (e) {
      // Ignored for smoother operation
    }
    return "Moving...";
  }

  // Cleanup old records
  void _cleanupOldHistory(String uid) async {
    DateTime cutoff =
        DateTime.now().subtract(const Duration(days: _historyRetentionDays));
    var old = await _firestore
        .collection('users')
        .doc(uid)
        .collection('insights_history')
        .where('arrivalTime', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    for (var doc in old.docs) doc.reference.delete();
  }
}

