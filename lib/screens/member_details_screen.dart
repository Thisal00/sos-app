import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MemberDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const MemberDetailsScreen(
      {super.key, required this.userData, required this.userId});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  String _address = "Fetching location details...";
  List<LatLng> _historyPoints = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _getAddress();
    _fetchHistoryForDate(_selectedDate);
  }

  // Fetch location history for selected date
  Future<void> _fetchHistoryForDate(DateTime date) async {
    setState(() {
      _isLoadingHistory = true;
      _historyPoints.clear();
    });

    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('locationHistory')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: false)
          .get();

      List<LatLng> points = [];
      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data.containsKey('lat') && data.containsKey('lng')) {
          points.add(LatLng(data['lat'], data['lng']));
        }
      }

      setState(() {
        _historyPoints = points;
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("History Fetch Error: $e");
      setState(() => _isLoadingHistory = false);
    }
  }

  // Premium Address Fetcher
  Future<void> _getAddress() async {
    try {
      if (widget.userData['lat'] == null || widget.userData['lng'] == null) {
        setState(() => _address = "Coordinates unavailable");
        return;
      }
      List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.userData['lat'], widget.userData['lng']);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        setState(() {
          _address = "${p.street}, ${p.locality}, ${p.subAdministrativeArea}";
        });
      }
    } catch (e) {
      setState(() => _address = "Address details not found");
    }
  }

  // Date Picker Logic
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.deepOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchHistoryForDate(picked);
    }
  }

  // Action: Call Member
  Future<void> _makeCall() async {
    final phone = widget.userData['phone'];
    if (phone != null && phone.toString().isNotEmpty) {
      await launchUrl(Uri.parse("tel:$phone"));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No phone number registered")));
    }
  }

  // Action: Open Google Maps for Navigation
  Future<void> _openGoogleMaps() async {
    final lat = widget.userData['lat'];
    final lng = widget.userData['lng'];
    if (lat != null && lng != null) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    double lat = (widget.userData['lat'] ?? 6.9271).toDouble();
    double lng = (widget.userData['lng'] ?? 79.8612).toDouble();
    LatLng userPos = LatLng(lat, lng);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            options: MapOptions(initialCenter: userPos, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sos',
              ),
              if (_historyPoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                      points: _historyPoints,
                      strokeWidth: 5,
                      color: Colors.indigo.withOpacity(0.6))
                ]),
              MarkerLayer(markers: [
                Marker(
                  point: userPos,
                  width: 60,
                  height: 60,
                  child: const Icon(Icons.location_on,
                      color: Colors.deepOrange, size: 45),
                ),
              ]),
            ],
          ),

          // Top Navigation Bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                    Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                _buildDateSelector(),
              ],
            ),
          ),

          // Member Detail Card (Scrollable to prevent overflow)
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: SingleChildScrollView(
                // Prevent Bottom Overflow
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(lat, lng),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 25),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildCircularButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Row(
          children: [
            const Icon(Icons.history_toggle_off_rounded,
                color: Colors.deepOrange, size: 18),
            const SizedBox(width: 8),
            Text(DateFormat('MMM dd').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double lat, double lng) {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.deepOrange.shade50,
          child: Text(widget.userData['name']?[0].toUpperCase() ?? "?",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.userData['name'] ?? "Member",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              Text(_address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(Icons.speed,
            "${(widget.userData['speed'] ?? 0).toInt()} km/h", "Speed"),
        _buildStatItem(Icons.battery_4_bar,
            "${widget.userData['battery'] ?? 0}%", "Battery"),
        _buildStatItem(
            Icons.sensors, widget.userData['status'] ?? "Active", "Status"),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openGoogleMaps,
            icon: const Icon(Icons.navigation_outlined, color: Colors.white),
            label: const Text("Navigate",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _makeCall,
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text("Call Member",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
        ),
      ],
    );
  }
}
