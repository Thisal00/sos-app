import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Screens
import '../screens/member_details_screen.dart';

class FamilyMemberList extends StatefulWidget {
  final String familyCode;
  const FamilyMemberList({super.key, required this.familyCode});

  @override
  State<FamilyMemberList> createState() => _FamilyMemberListState();
}

class _FamilyMemberListState extends State<FamilyMemberList> {
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _adminUid = "";
  bool _isAdminLoaded = false;
  Position? _myCurrentPosition;

  @override
  void initState() {
    super.initState();
    _fetchAdminStatus();
    _forceUpdateMyPosition(); // Force fetch location when screen loads
  }

  // Force fetch my exact location so distances calculate instantly
  Future<void> _forceUpdateMyPosition() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      if (mounted) {
        setState(() {
          _myCurrentPosition = pos;
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial position: $e");
    }
  }

  // Identify who created the family to assign Admin privileges
  Future<void> _fetchAdminStatus() async {
    var doc = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyCode)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _adminUid = doc.data()?['createdBy'] ?? "";
        _isAdminLoaded = true;
      });
    }
  }

  // Reverse Geocoding: Get City/Area name from Lat/Lng safely
  Future<String> _getAddress(double? lat, double? lng) async {
    if (lat == null || lng == null) return "Locating...";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(
              const Duration(seconds: 3)); // Add timeout to prevent freezing
      if (placemarks.isNotEmpty) {
        String locality = placemarks[0].locality ?? '';
        String subAdmin = placemarks[0].subAdministrativeArea ?? '';

        if (locality.isNotEmpty && subAdmin.isNotEmpty) {
          return "$locality, $subAdmin";
        } else if (locality.isNotEmpty) {
          return locality;
        } else if (subAdmin.isNotEmpty) {
          return "Nearby $subAdmin";
        }
      }
      return "Pinned Location";
    } catch (e) {
      return "Moving...";
    }
  }

  // Calculate distance between 'Me' and family member
  String _calculateDistance(double? lat, double? lng, Position? myPos) {
    if (lat == null || lng == null || myPos == null) return "---";
    double distance =
        Geolocator.distanceBetween(myPos.latitude, myPos.longitude, lat, lng);
    return distance < 1000
        ? "${distance.toInt()}m"
        : "${(distance / 1000).toStringAsFixed(1)}km";
  }

  // Admin Security: Trigger Local Notification with OTP
  Future<void> _initiateMemberRemoval(
      String memberUid, String memberName) async {
    final int otpCode = Random().nextInt(9000) + 1000;

    final plugin = FlutterLocalNotificationsPlugin();

    const androidDetails = AndroidNotificationDetails(
        'admin_security', 'Security Alerts',
        channelDescription: 'Used for administrative verification codes',
        importance: Importance.max,
        priority: Priority.high);

    await plugin.show(
        id: 1,
        title: "Member Removal OTP",
        body: "Verification code to remove $memberName: $otpCode",
        notificationDetails:
            const NotificationDetails(android: androidDetails));

    _showOtpDialog(memberUid, memberName, otpCode.toString());
  }

  // Verify OTP via Dialog before executing database removal
  void _showOtpDialog(String memberUid, String memberName, String correctOtp) {
    TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Admin Verification",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "Enter the OTP sent to your notification to remove $memberName.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (otpController.text.trim() == correctOtp) {
                // Verified: Disconnect user from family
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberUid)
                    .update({'familyCode': ""});

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("$memberName has been removed."),
                      backgroundColor: Colors.green));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Invalid OTP code."),
                    backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Verify",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentUserAdmin = _currentUid == _adminUid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('familyCode', isEqualTo: widget.familyCode)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange));
        }
        var members = snapshot.data?.docs ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            var data = members[index].data() as Map<String, dynamic>;
            String uid = members[index].id;

            // Hide 'Me' from the family list
            if (uid == _currentUid) return const SizedBox.shrink();

            String name = data['name'] ?? 'Member';
            String status = data['status'] ?? 'Online';
            bool isOnline = data['isOnline'] ?? false;
            double speed = (data['speed'] ?? 0.0).toDouble();

            // FIXED THE BATTERY GLITCH HERE (Checking both possible field names just in case)
            int battery = -1;
            if (data.containsKey('batteryLevel') &&
                data['batteryLevel'] != null) {
              battery = (data['batteryLevel'] as num).toInt();
            } else if (data.containsKey('battery') && data['battery'] != null) {
              battery = (data['battery'] as num).toInt();
            }

            bool isLowBattery = battery != -1 && battery <= 20;
            String batteryText = battery == -1 ? "--%" : "$battery%";

            // Dynamic UI color mapping
            Color statusColor = isOnline ? Colors.green : Colors.grey;
            if (status.contains("Driving")) statusColor = Colors.purple;
            if (status.contains("Walking")) statusColor = Colors.orange;

            return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MemberDetailsScreen(userData: data, userId: uid))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    // Avatar UI
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: statusColor.withOpacity(0.1),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: statusColor)),
                    ),
                    const SizedBox(width: 15),
                    // Member Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          FutureBuilder<String>(
                            future: _getAddress(data['lat'], data['lng']),
                            builder: (context, addr) => Text(
                                addr.data ?? "Locating...",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                  _calculateDistance(data['lat'], data['lng'],
                                      _myCurrentPosition),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                              if (speed > 5) ...[
                                const SizedBox(width: 8),
                                Text("•  ${speed.toInt()} km/h",
                                    style: const TextStyle(
                                        color: Colors.purple,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                              const SizedBox(width: 8),
                              Icon(
                                  isLowBattery
                                      ? Icons.battery_alert_rounded
                                      : (battery == -1
                                          ? Icons.battery_unknown_rounded
                                          : Icons.battery_full_rounded),
                                  size: 14,
                                  color:
                                      isLowBattery ? Colors.red : Colors.grey),
                              const SizedBox(width: 2),
                              Text(batteryText,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isLowBattery
                                          ? Colors.red
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Removal Button for Family Admin
                    if (isCurrentUserAdmin)
                      IconButton(
                        icon: const Icon(Icons.person_remove_rounded,
                            color: Colors.redAccent, size: 22),
                        onPressed: () => _initiateMemberRemoval(uid, name),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
