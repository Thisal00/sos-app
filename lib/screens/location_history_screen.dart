import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final MapController _mapController = MapController();

  DateTime _selectedDate = DateTime.now();
  int _lastPointCount = 0;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
  }

  // Royal Date Picker
  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogTheme: Theme.of(context).dialogTheme.copyWith(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _lastPointCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Route History",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5)),
        actions: [
          IconButton(
            onPressed: () => _selectDate(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.deepOrange, size: 20),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // LIVE DATA STREAM
      body: currentUser == null
          ? const Center(child: Text("User not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .collection('locationHistory')
                  .where('timestamp',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                  .where('timestamp',
                      isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _lastPointCount == 0) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  );
                }

                List<LatLng> currentPoints = [];
                List<Map<String, dynamic>> currentData = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  for (var doc in snapshot.data!.docs) {
                    var locData = doc.data() as Map<String, dynamic>;
                    if (locData.containsKey('lat') &&
                        locData.containsKey('lng')) {
                      currentPoints.add(LatLng(
                          (locData['lat'] as num).toDouble(),
                          (locData['lng'] as num).toDouble()));
                      currentData.add(locData);
                    }
                  }

                  // Auto-Center to the latest movement point safely
                  if (currentPoints.length != _lastPointCount &&
                      currentPoints.isNotEmpty) {
                    _lastPointCount = currentPoints.length;

                    if (_isMapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _mapController.move(currentPoints.last, 14.5);
                      });
                    }
                  }
                } else {
                  _lastPointCount = 0;
                }

                return Column(
                  children: [
                    // Interactive Map Section
                    Expanded(
                      flex: 3,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(31),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                    initialCenter: currentPoints.isNotEmpty
                                        ? currentPoints.last
                                        : const LatLng(6.9271, 79.8612),
                                    initialZoom: 14.5,
                                    onMapReady: () {
                                      setState(() {
                                        _isMapReady = true;
                                      });
                                    }),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.sos',
                                  ),
                                  if (currentPoints.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: currentPoints,
                                          strokeWidth: 5.0,
                                          color: Colors.deepOrange
                                              .withOpacity(0.8),
                                          strokeJoin: StrokeJoin.round,
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ],
                                    ),
                                  if (currentPoints.isNotEmpty)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: currentPoints.first,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                              Icons.trip_origin_rounded,
                                              color: Colors.green,
                                              size: 24),
                                        ),
                                        Marker(
                                          point: currentPoints.last,
                                          width: 50,
                                          height: 50,
                                          child: const Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.deepOrange,
                                              size: 38),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Royal Movement Timeline
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 20,
                                offset: const Offset(0, -5))
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 15, bottom: 5),
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      DateFormat('EEEE, MMM d')
                                          .format(_selectedDate),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87)),
                                  Text("${currentData.length} checkpoints",
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: currentData.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 25, vertical: 10),
                                      itemCount: currentData.length,
                                      itemBuilder: (context, index) {
                                        // Reverse the list so the newest point is at the top of the list
                                        int reversedIndex =
                                            currentData.length - 1 - index;
                                        var data = currentData[reversedIndex];

                                        DateTime time =
                                            (data['timestamp'] as Timestamp)
                                                .toDate();
                                        double speed = (data['speed'] as num?)
                                                ?.toDouble() ??
                                            0.0;

                                        // Update logic for timeline connector drawing
                                        bool isFirstItemInList = index == 0;

                                        return IntrinsicHeight(
                                          child: Row(
                                            children: [
                                              Column(
                                                children: [
                                                  Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: isFirstItemInList
                                                          ? Colors.deepOrange
                                                          : Colors
                                                              .grey.shade300,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                    ),
                                                  ),
                                                  if (index !=
                                                      currentData.length - 1)
                                                    Expanded(
                                                        child: Container(
                                                            width: 2,
                                                            color: Colors.grey
                                                                .shade100)),
                                                ],
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 15),
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF8F9FB),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              DateFormat(
                                                                      'hh:mm a')
                                                                  .format(time),
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize:
                                                                      15)),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                              speed > 5
                                                                  ? "Moving"
                                                                  : "Stationary",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade500,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                        ],
                                                      ),
                                                      if (speed > 2)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 5),
                                                          decoration: BoxDecoration(
                                                              color: Colors
                                                                  .deepOrange
                                                                  .shade50,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12)),
                                                          child: Text(
                                                              "${speed.toStringAsFixed(0)} km/h",
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .deepOrange,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize:
                                                                      11)),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No movement recorded",
              style: TextStyle(
                  color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
