import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  DateTime _selectedDate = DateTime.now();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _familyCode;
  String? _selectedUserUid;

  @override
  void initState() {
    super.initState();
    _selectedUserUid = _currentUserId;
    _fetchFamilyCode();
  }

  Future<void> _fetchFamilyCode() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _familyCode = doc.data()?['familyCode']);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.deepOrange,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    HapticFeedback.lightImpact();
    final Uri googleMapsUrl = Uri.parse(
        "http://googleusercontent.com/maps.google.com/maps?q=loc:$lat,$lng");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open Google Maps!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    bool isViewingToday = _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Activity Insights",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildFamilySelector(),
          ),
          const SizedBox(height: 10),
          _buildDateSelector(),

          // Main Live Timeline Section
          Expanded(
            child: _selectedUserUid == null
                ? const SizedBox()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(_selectedUserUid)
                        .collection('insights_history')
                        .where('arrivalTime',
                            isGreaterThanOrEqualTo:
                                Timestamp.fromDate(startOfDay))
                        .where('arrivalTime',
                            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                        .orderBy('arrivalTime', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.deepOrange));
                      }

                      var places = snapshot.data?.docs ?? [];

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 15.0),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: _buildSummaryCard(
                                          "Places Visited",
                                          "${places.length}",
                                          Icons.place_rounded)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildSummaryCard(
                                          "Activity Level",
                                          places.length > 3 ? "High" : "Normal",
                                          Icons.timeline_rounded)),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 24.0, top: 10.0, bottom: 20.0),
                              child: Text("Daily Timeline",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.grey.shade800,
                                      letterSpacing: -0.5)),
                            ),
                          ),

                          // LIVE CURRENT LOCATION TRACKER
                          if (isViewingToday && _selectedUserUid != null)
                            SliverToBoxAdapter(
                              child: _buildLiveLocationTracker(),
                            ),

                          if (places.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 30.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(30),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.03),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10))
                                          ],
                                          shape: BoxShape.circle),
                                      child: Icon(Icons.location_off_rounded,
                                          size: 50,
                                          color: Colors.grey.shade300),
                                    ),
                                    const SizedBox(height: 25),
                                    Text("No Places Visited Yet",
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey.shade800)),
                                    const SizedBox(height: 10),
                                    Text(
                                        "The timeline will automatically update\nonce the user stops at a location.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5)),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20.0),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    var data = places[index].data()
                                        as Map<String, dynamic>;
                                    return _buildModernTimelineItem(data, false,
                                        index == places.length - 1);
                                  },
                                  childCount: places.length,
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 120)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Auto-Updating Live Location Widget
  Widget _buildLiveLocationTracker() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const SizedBox();

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        double speed = (userData['speed'] as num?)?.toDouble() ?? 0.0;
        String status = userData['status'] ?? 'Unknown';
        String currentPlace = userData['currentPlace'] ?? 'Locating...';

        var rawLat = userData['lat'];
        var rawLng = userData['lng'];
        double? lat = rawLat != null ? (rawLat as num).toDouble() : null;
        double? lng = rawLng != null ? (rawLng as num).toDouble() : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                    width: 70,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 25),
                          Text("LIVE",
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade600,
                                  fontSize: 14))
                        ])),
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      const SizedBox(height: 25),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.green.shade200, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.green.withOpacity(0.4),
                                  blurRadius: 10)
                            ]),
                      ),
                      Expanded(
                          child:
                              Container(width: 2, color: Colors.grey.shade300)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(speed > 5 ? "Moving towards..." : currentPlace,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1.3)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Icon(
                                  speed > 5
                                      ? Icons.directions_run
                                      : Icons.my_location_rounded,
                                  size: 14,
                                  color: Colors.green),
                              const SizedBox(width: 5),
                              Text(
                                  speed > 5
                                      ? "${speed.toStringAsFixed(0)} km/h"
                                      : status,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w700))
                            ]),
                            GestureDetector(
                              onTap: () {
                                if (lat != null && lng != null) {
                                  _openGoogleMaps(lat, lng);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(children: [
                                  Icon(Icons.map_rounded,
                                      size: 12, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text("Map",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700))
                                ]),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFamilySelector() {
    return Container(
      height: 110,
      padding: const EdgeInsets.only(top: 10),
      child: _familyCode == null || _familyCode!.isEmpty
          ? Center(
              child: Text("Join a family to view insights",
                  style: TextStyle(color: Colors.grey.shade500)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('familyCode', isEqualTo: _familyCode)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.deepOrange));
                }

                var members = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    var data = members[index].data() as Map<String, dynamic>;
                    String mUid = members[index].id;
                    bool isSelected = _selectedUserUid == mUid;
                    String name = data['name'] ?? 'User';
                    String initial =
                        name.isNotEmpty ? name[0].toUpperCase() : '?';

                    int battery = 0;
                    var rawBattery = data['batteryLevel'] ?? data['battery'];
                    if (rawBattery != null) {
                      battery = (rawBattery as num).toInt();
                    }

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedUserUid = mUid);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 25),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isSelected
                                            ? Colors.deepOrange
                                            : Colors.transparent,
                                        width: 3),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: Colors.deepOrange
                                                    .withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5))
                                          ]
                                        : [],
                                  ),
                                  child: CircleAvatar(
                                    radius: isSelected ? 28 : 25,
                                    backgroundColor: isSelected
                                        ? Colors.deepOrange
                                        : Colors.grey.shade100,
                                    child: Text(initial,
                                        style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w900,
                                            fontSize: isSelected ? 22 : 18)),
                                  ),
                                ),
                                if (battery > 0)
                                  Positioned(
                                    bottom: -5,
                                    right: -5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: battery <= 15
                                            ? Colors.red
                                            : Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: Text(
                                        "$battery%",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              mUid == _currentUserId
                                  ? "Me"
                                  : name.split(" ")[0],
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.deepOrange
                                      : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: InkWell(
        onTap: () => _selectDate(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Selected Timeline Date",
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.edit_calendar_rounded,
                  color: Colors.deepOrange, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.deepOrange, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernTimelineItem(
      Map<String, dynamic> data, bool isFirst, bool isLast) {
    Timestamp? arrival = data['arrivalTime'];
    String timeStr = arrival != null
        ? DateFormat('hh:mm a').format(arrival.toDate())
        : "Just now";
    String placeName = data['placeName'] ?? "Locating...";

    var rawLat = data['latitude'] ?? data['lat'];
    var rawLng = data['longitude'] ?? data['lng'];

    double? lat = rawLat != null ? (rawLat as num).toDouble() : null;
    double? lng = rawLng != null ? (rawLng as num).toDouble() : null;

    Color themeColor = Colors.teal;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
              width: 70,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    Text(timeStr,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade600,
                            fontSize: 12))
                  ])),
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(width: 2, height: 25, color: Colors.grey.shade300),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: themeColor, width: 4)),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(width: 2, color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.transparent, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(placeName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.3)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.history_rounded,
                            size: 14, color: themeColor),
                        const SizedBox(width: 5),
                        Text("Visited here",
                            style: TextStyle(
                                fontSize: 12,
                                color: themeColor,
                                fontWeight: FontWeight.w700))
                      ]),
                      GestureDetector(
                        onTap: () {
                          if (lat != null && lng != null) {
                            _openGoogleMaps(lat, lng);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Location coordinates not available.")));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Icon(Icons.map_rounded,
                                size: 12, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text("Map",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700))
                          ]),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
