import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Main SOS Function
  Future<void> sendSOS(List<String> recipients) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1.  Location
      Position position = await _determinePosition();

      // 2. gogle Maps Link
      String googleMapsLink =
          "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      String message = "🚨 SOS! I need help!\nMy Location: $googleMapsLink";

      // 3.  Firestore  Update
      await _firestore.collection('users').doc(user.uid).update({
        'isSOS': true, // SOS Mode On
        'lat': position.latitude, // අලුත්ම Location එක
        'lng': position.longitude,
        'lastActive': FieldValue.serverTimestamp(),
      });

      //  SMS App Open
      if (recipients.isNotEmpty) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: recipients.join(','),
          queryParameters: <String, String>{
            'body': message,
          },
        );

        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        } else {
          print("Could not launch SMS");
        }
      }
    } catch (e) {
      print("Error sending SOS: $e");
      rethrow;
    }
  }

  //  SOS Function
  Future<void> stopSOS() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isSOS': false, // SOS Mode Off
    });
  }

  //  Location Permission  Function
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }
}
