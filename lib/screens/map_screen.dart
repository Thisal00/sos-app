import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final String familyCode;
  const MapScreen({super.key, required this.familyCode});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final Distance _distanceCalculator = const Distance();

  // Live Location & Map Data
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _zonesSubscription;
  StreamSubscription<QuerySnapshot>? _homeSubscription;

  LatLng? _currentLocation;
  LatLng? _homeLocation;

  String? _trackingUid;
  String _trackedAddress = "Locating address...";
  List<LatLng> _routePoints = [];

  final List<Color> _palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal
  ];
  final Map<String, Color> _userColors = {};
  int _colorIndex = 0;

  List<CircleMarker> _safeZoneCircles = [];
  List<Marker> _safeZoneMarkers = [];
  List<Polyline> _memberPaths = [];

  @override
  void initState() {
    super.initState();
    _startLiveLocationStream();
    _fetchHomeLocation();
    _fetchSafeZones();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.familyCode != oldWidget.familyCode &&
        widget.familyCode.isNotEmpty) {
      _fetchHomeLocation();
      _fetchSafeZones();
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _zonesSubscription?.cancel();
    _homeSubscription?.cancel();
    super.dispose();
  }

  void _startLiveLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() => _currentLocation =
            LatLng(initialPos.latitude, initialPos.longitude));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_currentLocation!, 15.0);
        });
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2),
      ).listen((Position position) {
        if (mounted) {
          setState(() =>
              _currentLocation = LatLng(position.latitude, position.longitude));

          if (_trackingUid == null && _currentLocation != null) {
            _mapController.move(_currentLocation!, _mapController.camera.zoom);
          }
        }
      });
    } catch (e) {
      debugPrint("Map Location Error: $e");
    }
  }

  void _centerOnMyLocation() {
    HapticFeedback.lightImpact();
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
      setState(() {
        _trackingUid = null;
        _routePoints.clear();
        _memberPaths.clear();
      });
    }
  }

  Future<void> _fetchAndDrawUserRoute(String uid, Color color) async {
    var snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insights_history')
        .orderBy('arrivalTime', descending: true)
        .limit(30)
        .get();

    if (snap.docs.isNotEmpty) {
      List<LatLng> points = [];
      for (var doc in snap.docs) {
        var d = doc.data();
        if (d.containsKey('lat') && d.containsKey('lng')) {
          points.add(LatLng(
              (d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()));
        } else if (d.containsKey('latitude')) {
          points.add(LatLng((d['latitude'] as num).toDouble(),
              (d['longitude'] as num).toDouble()));
        }
      }
      if (mounted && points.isNotEmpty) {
        setState(() {
          _routePoints = points.reversed.toList();
          _memberPaths = [
            Polyline(
                points: _routePoints,
                strokeWidth: 5.0,
                color: color.withOpacity(0.8),
                strokeJoin: StrokeJoin.round,
                strokeCap: StrokeCap.round)
          ];
        });
      }
    }
  }

  void _fetchHomeLocation() {
    if (widget.familyCode.isEmpty) return;

    _homeSubscription?.cancel();
    _homeSubscription = FirebaseFirestore.instance
        .collection('families')
        .where('inviteCode', isEqualTo: widget.familyCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        if (data.containsKey('homeLat') &&
            data.containsKey('homeLng') &&
            mounted) {
          setState(() => _homeLocation = LatLng(
              (data['homeLat'] as num).toDouble(),
              (data['homeLng'] as num).toDouble()));
        }
      }
    });
  }

  void _fetchSafeZones() {
    if (widget.familyCode.isEmpty) return;

    _zonesSubscription?.cancel();
    _zonesSubscription = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyCode)
        .collection('zones')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      List<CircleMarker> circles = [];
      List<Marker> markers = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        LatLng pos = LatLng(
            (data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());

        circles.add(CircleMarker(
          point: pos,
          color: Colors.teal.withOpacity(0.2),
          borderColor: Colors.teal,
          borderStrokeWidth: 2,
          radius: (data['radius'] ?? 200).toDouble(),
          useRadiusInMeter: true,
        ));

        markers.add(Marker(
          point: pos,
          width: 80,
          height: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_rounded, color: Colors.teal, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.teal, width: 1)),
                child: Text(
                  data['name'] ?? 'Zone',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
              )
            ],
          ),
        ));
      }

      setState(() {
        _safeZoneCircles = circles;
        _safeZoneMarkers = markers;
      });
    });
  }

  Future<void> _setHomeLocation(LatLng point) async {
    HapticFeedback.heavyImpact();
    var snapshot = await FirebaseFirestore.instance
        .collection('families')
        .where('inviteCode', isEqualTo: widget.familyCode)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(snapshot.docs.first.id)
          .update({
        'homeLat': point.latitude,
        'homeLng': point.longitude,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Home Location Updated! 🏠"),
            backgroundColor: Colors.green));
      }
    }
  }

  Future<void> _getAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];

        String locality = place.locality ?? '';
        String subAdmin = place.subAdministrativeArea ?? '';
        String street = place.street ?? '';

        String address = "";

        if (street.isNotEmpty && locality.isNotEmpty) {
          address = "$street, $locality";
        } else if (locality.isNotEmpty && subAdmin.isNotEmpty) {
          address = "$locality, $subAdmin";
        } else if (locality.isNotEmpty) {
          address = locality;
        } else {
          address = "Pinned Location";
        }

        setState(() => _trackedAddress = address);
      }
    } catch (e) {
      if (mounted) setState(() => _trackedAddress = "Address not available");
    }
  }

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    HapticFeedback.lightImpact();
    final Uri googleMapsUrl =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_trackingUid == null ? "Family Map" : "📡 Live Tracking",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _trackingUid == null ? Colors.black87 : Colors.red)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_trackingUid != null)
            Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: ActionChip(
                backgroundColor: Colors.red.shade50,
                side: BorderSide.none,
                label: const Text("STOP",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                avatar: const Icon(Icons.stop_circle_rounded,
                    color: Colors.red, size: 18),
                onPressed: _centerOnMyLocation,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange))
              : StreamBuilder<QuerySnapshot>(
                  stream: widget.familyCode.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .where('familyCode', isEqualTo: widget.familyCode)
                          .snapshots()
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    // Add Zones to Map
                    List<Marker> markers = [..._safeZoneMarkers];
                    List<CircleMarker> circles = [..._safeZoneCircles];
                    Map<String, dynamic>? liveTrackedData;

                    // Add Home Location to Map
                    if (_homeLocation != null) {
                      circles.add(CircleMarker(
                          point: _homeLocation!,
                          color: Colors.green.withOpacity(0.15),
                          borderColor: Colors.green,
                          borderStrokeWidth: 2,
                          radius: 100,
                          useRadiusInMeter: true));
                      markers.add(Marker(
                          point: _homeLocation!,
                          width: 80,
                          height: 80,
                          child: const Column(children: [
                            Icon(Icons.home_rounded,
                                color: Colors.green, size: 35),
                            Text("Home",
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                    fontSize: 13))
                          ])));
                    }

                    // Add My Location
                    markers.add(Marker(
                        point: _currentLocation!,
                        width: 60,
                        height: 60,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.my_location,
                                color: Colors.blue, size: 30))));

                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        if (doc.id == _myUid) continue;
                        var data = doc.data() as Map<String, dynamic>;

                        if (!_userColors.containsKey(doc.id)) {
                          _userColors[doc.id] =
                              _palette[_colorIndex % _palette.length];
                          _colorIndex++;
                        }
                        Color memberColor = _userColors[doc.id]!;

                        if (data.containsKey('currentLocation') ||
                            (data.containsKey('lat') &&
                                data.containsKey('lng'))) {
                          LatLng pos;
                          if (data.containsKey('currentLocation')) {
                            GeoPoint gp = data['currentLocation'];
                            pos = LatLng(gp.latitude, gp.longitude);
                          } else {
                            pos = LatLng((data['lat'] as num).toDouble(),
                                (data['lng'] as num).toDouble());
                          }

                          String name = data['name']?.toString() ?? 'Family';
                          String initial =
                              name.isNotEmpty ? name[0].toUpperCase() : '?';
                          bool isSOS = data['isSOS'] ?? false;

                          if (doc.id == _trackingUid) {
                            liveTrackedData = data;
                            if (data.containsKey('currentPlace') &&
                                data['currentPlace'] != "Moving...") {
                              _trackedAddress = data['currentPlace'];
                            }

                            // PRO FIX: Move camera to tracked user smoothly
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _trackingUid != null) {
                                _mapController.move(
                                    pos, _mapController.camera.zoom);
                              }
                            });
                          }

                          // Other Family Members
                          markers.add(Marker(
                            point: pos,
                            width: 80,
                            height: 80,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _fetchAndDrawUserRoute(doc.id, memberColor);
                                setState(() {
                                  _trackingUid = doc.id;
                                  _trackedAddress =
                                      data['currentPlace'] ?? "Locating...";
                                });
                                if (!data.containsKey('currentPlace')) {
                                  _getAddress(pos.latitude, pos.longitude);
                                }
                              },
                              child: Column(
                                children: [
                                  CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          isSOS ? Colors.red : memberColor,
                                      child: Text(initial,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900))),
                                  Icon(Icons.location_on,
                                      color: isSOS ? Colors.red : memberColor,
                                      size: 38),
                                ],
                              ),
                            ),
                          ));
                        }
                      }
                    }

                    return Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentLocation!,
                            initialZoom: 15.0,
                            onLongPress: (tapPos, point) =>
                                _setHomeLocation(point),
                            onPositionChanged:
                                (MapCamera camera, bool hasGesture) {
                              if (hasGesture && _trackingUid != null) {
                                setState(() => _trackingUid = null);
                              }
                            },
                          ),
                          children: [
                            TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.sos'),
                            PolylineLayer(polylines: _memberPaths),
                            CircleLayer(circles: circles),
                            MarkerLayer(markers: markers),
                          ],
                        ),

                        // My Location Button
                        Positioned(
                          bottom: _trackingUid != null ? 360 : 110,
                          right: 20,
                          child: FloatingActionButton(
                              heroTag: "myLocationBtn",
                              onPressed: _centerOnMyLocation,
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.my_location_rounded,
                                  color: Colors.blueAccent)),
                        ),

                        // Live Tracking Info Card
                        if (_trackingUid != null && liveTrackedData != null)
                          Positioned(
                            bottom: 110,
                            left: 15,
                            right: 15,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 25,
                                        offset: const Offset(0, 10))
                                  ]),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                          radius: 25,
                                          backgroundColor:
                                              Colors.deepOrange.shade50,
                                          child: Text(
                                              (liveTrackedData!['name']
                                                          as String)
                                                      .isNotEmpty
                                                  ? (liveTrackedData!['name']
                                                          as String)[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.deepOrange))),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                liveTrackedData!['name'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w900),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1),
                                            Text(
                                              _currentLocation != null &&
                                                      liveTrackedData!['lat'] !=
                                                          null &&
                                                      liveTrackedData!['lng'] !=
                                                          null
                                                  ? "${(_distanceCalculator.as(LengthUnit.Meter, _currentLocation!, LatLng((liveTrackedData!['lat'] as num).toDouble(), (liveTrackedData!['lng'] as num).toDouble())) / 1000).toStringAsFixed(1)} km away"
                                                  : "Calculating...",
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text(
                                              liveTrackedData!['status']
                                                      ?.toString() ??
                                                  "Active",
                                              style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12))),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Row(children: [
                                      const Icon(Icons.location_on_rounded,
                                          size: 20, color: Colors.deepOrange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(_trackedAddress,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)))
                                    ]),
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                          Icons.speed,
                                          "${(liveTrackedData!['speed'] as num?)?.toInt() ?? 0} km/h",
                                          "Speed"),

                                      // FIXED BATTERY BUG HERE TOO
                                      _buildStatItem(
                                          Icons.battery_std,
                                          "${liveTrackedData!['batteryLevel'] ?? liveTrackedData!['battery'] ?? 0}%",
                                          "Battery"),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: ElevatedButton.icon(
                                              onPressed: () => _openGoogleMaps(
                                                  (liveTrackedData!['lat'] as num)
                                                      .toDouble(),
                                                  (liveTrackedData!['lng'] as num)
                                                      .toDouble()),
                                              icon: const Icon(Icons.directions,
                                                  color: Colors.white,
                                                  size: 18),
                                              label: const Text("Navigate",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.blue.shade600,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 14)))),
                                      const SizedBox(width: 15),
                                      Expanded(
                                          child: ElevatedButton.icon(
                                              onPressed: () => _makeCall(
                                                  liveTrackedData!['phone']
                                                      ?.toString()),
                                              icon: const Icon(Icons.call,
                                                  color: Colors.white,
                                                  size: 18),
                                              label: const Text("Call",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade600,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 14)))),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
