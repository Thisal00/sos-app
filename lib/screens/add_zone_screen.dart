import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddZoneScreen extends StatefulWidget {
  final String familyCode;
  const AddZoneScreen({super.key, required this.familyCode});

  @override
  State<AddZoneScreen> createState() => _AddZoneScreenState();
}

class _AddZoneScreenState extends State<AddZoneScreen> {
  final TextEditingController _nameController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _selectedLocation = const LatLng(6.9271, 79.8612); // Default: Colombo
  double _radius = 200; // 200
  String _selectedType = 'Home';
  bool _isLoading = false;

  // Premium Zone Types with Icons
  final List<Map<String, dynamic>> _zoneTypes = [
    {'name': 'Home', 'icon': Icons.home_rounded},
    {'name': 'School', 'icon': Icons.school_rounded},
    {'name': 'Work', 'icon': Icons.work_rounded},
    {'name': 'Other', 'icon': Icons.location_on_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_selectedLocation, 15);
    }
  }

  void _saveZone() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please enter a name for the zone! 📛"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyCode)
          .collection('zones')
          .add({
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
        'radius': _radius,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Safe Zone Created Successfully! "),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error saving zone: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Add Safe Zone",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
      ),
      body: Column(
        children: [
          //  MAP VIEW (Premium Layout)
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onTap: (_, point) {
                      setState(() => _selectedLocation = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.sos',
                    ),
                    // Safe Zone Radius Circle
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _selectedLocation,
                        color: Colors.deepOrange.withOpacity(0.2),
                        borderStrokeWidth: 2,
                        borderColor: Colors.deepOrange,
                        radius: _radius,
                        useRadiusInMeter: true,
                      )
                    ]),
                    // Center Marker
                    MarkerLayer(markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 45),
                      )
                    ]),
                  ],
                ),
                // Locate Me Button
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    heroTag: "locate_btn",
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location_rounded,
                        color: Colors.deepOrange),
                    onPressed: _getCurrentLocation,
                  ),
                ),
                // Instructions Overlay
                Positioned(
                  top: 15,
                  left: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.touch_app_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Tap on the map to set the center point.",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          //  CONTROLS (Name, Type, Radius)
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone Name Field
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Zone Name",
                    hintText: "e.g., Kids School, My Home",
                    prefixIcon: Icon(Icons.edit_location_alt_rounded,
                        color: Colors.deepOrange.shade300),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                            color: Colors.deepOrange, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Premium Choice Chips (No more boring dropdowns!)
                const Text("Select Category",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _zoneTypes.map((type) {
                      bool isSelected = _selectedType == type['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(type['icon'],
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600),
                              const SizedBox(width: 5),
                              Text(type['name']),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: Colors.deepOrange,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            setState(() => _selectedType = type['name']);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 25),

                // Radius Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Alert Radius",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    Text("${_radius.toInt()} meters",
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange)),
                  ],
                ),
                const SizedBox(height: 5),
                Slider(
                  value: _radius,
                  min: 50, // Minimum 50m
                  max: 1000, // Maximum 1km
                  divisions: 19, // 50m steps
                  activeColor: Colors.deepOrange,
                  inactiveColor: Colors.deepOrange.shade100,
                  onChanged: (val) => setState(() => _radius = val),
                ),
                const SizedBox(height: 15),

                // Premium Gradient Save Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepOrange, Colors.orangeAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveZone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            "Save Safe Zone",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
