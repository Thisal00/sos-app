import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencySupportScreen extends StatefulWidget {
  const EmergencySupportScreen({super.key});

  @override
  State<EmergencySupportScreen> createState() => _EmergencySupportScreenState();
}

class _EmergencySupportScreenState extends State<EmergencySupportScreen> {
  String _currentAddress = "Locating your exact position...";
  bool _isLoadingLocation = true;
  String? _familyCode;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchFamilyCode();
  }

  Future<void> _fetchFamilyCode() async {
    if (_user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _familyCode = data?['familyCode']; // 🔥 Null-safe fetch
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          _currentAddress =
              "${placemarks[0].street}, ${placemarks[0].locality}, ${placemarks[0].administrativeArea}"
                  .replaceAll(RegExp(r'^, |, $'), '')
                  .replaceAll(', ,', ',');
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _makeCall(String number) async {
    HapticFeedback.heavyImpact(); // Vibration on call
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC), // iOS White
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Emergency Hub",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 👨‍👩‍👧‍👦 NOTIFYING FAMILY UI (Dynamic)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  const Text("NOTIFYING FAMILY GROUP",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 15),
                  _buildDynamicFamilyAvatars(),
                  const SizedBox(height: 10),
                  Text("All members will receive a critical alert",
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 👑 PUBLIC EMERGENCY SERVICES GRID
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Public Support",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.6,
              children: [
                _buildEmergencyCard(
                    "Police", "119", Icons.local_police_rounded, Colors.blue),
                _buildEmergencyCard("Ambulance", "1990",
                    Icons.medical_services_rounded, Colors.green),
                _buildEmergencyCard(
                    "Fire Dept", "110", Icons.fire_truck_rounded, Colors.red),
                _buildEmergencyCard(
                    "Accident", "117", Icons.car_crash_rounded, Colors.orange),
              ],
            ),

            const SizedBox(height: 30),

            // 📍 LIVE LOCATION CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white,
                  Colors.red.shade50.withOpacity(0.5)
                ]),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ]),
                    child: const Icon(Icons.my_location_rounded,
                        color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Your Current Address",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        _isLoadingLocation
                            ? const LinearProgressIndicator(minHeight: 2)
                            : Text(_currentAddress,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 📞 TRUSTED CONTACTS SECTION
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Trusted Contacts",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 15),
            _buildTrustedContactsList(),

            const SizedBox(height: 120), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  // Trusted Contacts List
  Widget _buildTrustedContactsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid)
          .collection('trusted_contacts')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20)),
            child: const Text("No trusted contacts added yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var contact =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String name = contact['name'] ?? "Unknown";
            String phone = contact['phone'] ?? "";
            String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02), blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepOrange.shade50,
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(phone,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _makeCall(phone),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.call, color: Colors.green, size: 20),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🔥 THE FIX: Safe Avatar Builder
  Widget _buildDynamicFamilyAvatars() {
    if (_familyCode == null || _familyCode!.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('familyCode', isEqualTo: _familyCode)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: Colors.deepOrange);
        }

        if (!snapshot.hasData) return const SizedBox();

        var members =
            snapshot.data!.docs.where((doc) => doc.id != _user?.uid).toList();

        if (members.isEmpty) {
          return Text("No family members found.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              List.generate(members.length > 4 ? 4 : members.length, (index) {
            // 🔥 Null-safe Name Fetching
            var data = members[index].data() as Map<String, dynamic>;
            String name = data['name'] ?? '?';
            String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

            return Align(
              widthFactor: 0.7,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors
                      .primaries[index % Colors.primaries.length].shade400,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEmergencyCard(
      String title, String number, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _makeCall(number),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                  Text(number,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
