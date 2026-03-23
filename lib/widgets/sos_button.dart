import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:telephony/telephony.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/push_notification_service.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  Timer? _timer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Telephony _telephony = Telephony.instance;
  bool _isRecording = false;

  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  int _shakeCount = 0;
  int _lastShakeTimestamp = 0;
  bool _isProcessingSOS = false;

  @override
  void initState() {
    super.initState();
    _startForegroundShakeDetection();
  }

  // ========================================================
  //  FOREGROUND SHAKE DETECTOR (UPDATED: Harder & 5 Shakes)
  // ========================================================
  void _startForegroundShakeDetection() {
    _shakeSubscription = accelerometerEvents.listen((event) async {
      if (_isProcessingSOS) return;

      double gX = event.x / 9.80665;
      double gY = event.y / 9.80665;
      double gZ = event.z / 9.80665;
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      //  FIX: 3.5G 
      if (gForce > 3.5) {
        int now = DateTime.now().millisecondsSinceEpoch;

        // 5 times shake  time  is  have  a 400 s
        if (now - _lastShakeTimestamp > 400) {
          _shakeCount++;
          _lastShakeTimestamp = now;

          // 5 times  shake system
          if (_shakeCount >= 5) {
            _shakeCount = 0;
            _handleShakeSOS();
          }
        }
      } else {
        // not to  4  time  shake  it  reset
        if (DateTime.now().millisecondsSinceEpoch - _lastShakeTimestamp >
            4000) {
          _shakeCount = 0;
        }
      }
    });
  }

  Future<void> _handleShakeSOS() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && doc.data()?['isSOS'] == true) return;

    HapticFeedback.vibrate();
    _triggerFullSOS();
  }

  void _startSOSCountdown() {
    int countdown = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (countdown > 1) {
                if (mounted) {
                  HapticFeedback.heavyImpact();
                  setDialogState(() => countdown--);
                }
              } else {
                timer.cancel();
                _timer = null;
                Navigator.pop(context);
                _triggerFullSOS();
              }
            });

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: Colors.white.withOpacity(0.95),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                title: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded,
                          color: Colors.red, size: 50),
                    ),
                    const SizedBox(height: 15),
                    const Text("EMERGENCY ALERT",
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 22)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Transmitting signals in...",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text("$countdown",
                        style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: Colors.red)),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    onPressed: () {
                      _timer?.cancel();
                      _timer = null;
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: const Text("CANCEL",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 16)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _triggerFullSOS() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isProcessingSOS) return;

    _isProcessingSOS = true;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Initiating Emergency Alert..."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 2));
        hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String mapLink =
          "http://googleusercontent.com/maps.google.com/?q=${pos.latitude},${pos.longitude}";

      String messageBody = hasInternet
          ? "[URGENT] Emergency SOS! I need help immediately. Live Location: $mapLink"
          : "[OFFLINE SOS] Emergency! I need help. Last known GPS: $mapLink";

      GetOptions fetchOptions = hasInternet
          ? const GetOptions(source: Source.serverAndCache)
          : const GetOptions(source: Source.cache);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(fetchOptions);

      String familyCode =
          (userDoc.data() as Map<String, dynamic>?)?['familyCode'] ?? '';
      String myName =
          (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Family Member';

      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'status': 'SOS ACTIVE',
        'isSOS': true,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'lastActive': FieldValue.serverTimestamp(),
      });

      if (familyCode.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('families')
            .doc(familyCode)
            .collection('chat')
            .add({
          'senderId': user.uid,
          'senderName': myName,
          'text': "System Alert: Emergency location shared.",
          'type': 'sos_location',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (hasInternet) {
          try {
            final usersSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('familyCode', isEqualTo: familyCode)
                .get();

            for (var doc in usersSnapshot.docs) {
              if (doc.id != user.uid) {
                final data = doc.data();
                final fcmToken = data['fcmToken'];

                if (fcmToken != null && fcmToken.toString().isNotEmpty) {
                  await PushNotificationService.sendPushMessage(
                    targetFcmToken: fcmToken,
                    title: "EMERGENCY SOS Alert",
                    body: "$myName is in danger! Open the app immediately.",
                  );
                }
              }
            }
          } catch (e) {
            debugPrint("SOS Push Notification Error: $e");
          }
        }
      }

      await _sendSmartEmergencyMessages(
          user.uid, familyCode, messageBody, fetchOptions);

      _startBackgroundAudioRecord(familyCode, user.uid, myName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(hasInternet ? Icons.check_circle : Icons.offline_bolt,
                    color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(hasInternet
                        ? "SOS Signal Sent. Capturing audio..."
                        : "Offline SOS Sent via SMS network.")),
              ],
            ),
            backgroundColor:
                hasInternet ? Colors.red.shade700 : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("SOS Error: $e");
      _isProcessingSOS = false;
    }
  }

  Future<void> _startBackgroundAudioRecord(
      String familyCode, String uid, String name) async {
    if (familyCode.isEmpty) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() => _isRecording = true);

        final dir = await getApplicationDocumentsDirectory();
        String filePath = '${dir.path}/sos_temp_audio.m4a';

        await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: filePath);

        await Future.delayed(const Duration(seconds: 10));

        if (_isRecording) {
          String? finalPath = await _audioRecorder.stop();
          setState(() => _isRecording = false);

          if (finalPath != null) {
            File audioFile = File(finalPath);
            List<int> fileBytes = await audioFile.readAsBytes();
            String base64Audio = base64Encode(fileBytes);

            await FirebaseFirestore.instance
                .collection('families')
                .doc(familyCode)
                .collection('chat')
                .add({
              'senderId': uid,
              'senderName': name,
              'text': "System Alert: Surrounding audio captured.",
              'audioBase64': base64Audio,
              'type': 'sos_audio',
              'timestamp': FieldValue.serverTimestamp(),
            });

            if (await audioFile.exists()) {
              await audioFile.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Audio Record Error: $e");
    }
  }

  Future<void> _sendSmartEmergencyMessages(String uid, String familyCode,
      String messageBody, GetOptions options) async {
    try {
      List<String> phoneNumbers = [];

      var trustedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trusted_contacts')
          .get(options);

      for (var doc in trustedSnap.docs) {
        if (doc.data().containsKey('phone')) {
          String cleanNum =
              doc['phone'].toString().replaceAll(RegExp(r'[^0-9+]'), '');
          if (cleanNum.isNotEmpty) phoneNumbers.add(cleanNum);
        }
      }

      if (phoneNumbers.isEmpty && familyCode.isNotEmpty) {
        var familySnap = await FirebaseFirestore.instance
            .collection('users')
            .where('familyCode', isEqualTo: familyCode)
            .get(options);

        for (var doc in familySnap.docs) {
          if (doc.id != uid && doc.data().containsKey('phone')) {
            String cleanNum =
                doc['phone'].toString().replaceAll(RegExp(r'[^0-9+]'), '');
            if (cleanNum.isNotEmpty) phoneNumbers.add(cleanNum);
          }
        }
      }

      if (phoneNumbers.isEmpty) return;

      bool smsSentInBackground = false;
      bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;

      if (permissionsGranted != null && permissionsGranted) {
        for (String number in phoneNumbers) {
          await _telephony.sendSms(to: number, message: messageBody);
        }
        smsSentInBackground = true;
      }

      if (!smsSentInBackground) {
        String allPhones = phoneNumbers.join(",");
        Uri smsUri = Uri.parse(
            "sms:$allPhones?body=${Uri.encodeComponent(messageBody)}");
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Msg App Open Error: $e");
    }
  }

  Future<void> _stopSOS() async {
    HapticFeedback.lightImpact();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isRecording) {
      await _audioRecorder.stop();
      setState(() => _isRecording = false);
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'status': 'Online',
      'isSOS': false,
    });

    _isProcessingSOS = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SOS Alert has been cancelled."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        bool isSOSActive = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isSOSActive =
              (snapshot.data!.data() as Map<String, dynamic>)['isSOS'] ?? false;
        }

        return GestureDetector(
          onTap: isSOSActive ? _stopSOS : _startSOSCountdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSOSActive
                    ? [Colors.grey.shade800, Colors.grey.shade600]
                    : [Colors.red.shade800, Colors.redAccent.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color:
                      isSOSActive ? Colors.grey.shade400 : Colors.red.shade300,
                  width: 2),
              boxShadow: [
                if (!isSOSActive)
                  BoxShadow(
                    color: Colors.red.withOpacity(0.6),
                    blurRadius: 25,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5)
                          ],
                        ),
                        child: Icon(
                          isSOSActive
                              ? (_isRecording
                                  ? Icons.mic_rounded
                                  : Icons.stop_circle_rounded)
                              : Icons.sos_rounded,
                          color: isSOSActive
                              ? Colors.grey.shade800
                              : Colors.red.shade700,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSOSActive ? "CANCEL SOS" : "EMERGENCY SOS",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isSOSActive
                                  ? (_isRecording
                                      ? "Capturing audio..."
                                      : "Tap to turn off")
                                  : "Shake phone hard 5 times or tap",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      isSOSActive
                          ? Icons.close_rounded
                          : Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
