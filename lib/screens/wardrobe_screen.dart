import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // Premium Colors Palette
  final List<Map<String, dynamic>> _colors = [
    {'name': 'White', 'color': Colors.white},
    {'name': 'Black', 'color': const Color(0xFF1C1C1E)},
    {'name': 'Grey', 'color': const Color(0xFF8E8E93)},
    {'name': 'Navy', 'color': const Color(0xFF1B263B)},
    {'name': 'Sky Blue', 'color': const Color(0xFF89CFF0)},
    {'name': 'Beige', 'color': const Color(0xFFD5CAB3)},
    {'name': 'Maroon', 'color': const Color(0xFF641E16)},
    {'name': 'Blush', 'color': const Color(0xFFF5B7B1)},
    {'name': 'Olive', 'color': const Color(0xFF556B2F)},
  ];

  late Map<String, dynamic> _selectedTop;
  late Map<String, dynamic> _selectedBottom;

  // Live Data Variables
  bool _isLoadingData = true;
  String _weatherCondition = "Analyzing Context...";
  IconData _weatherIcon = Icons.sync_rounded;
  Color _weatherColor = Colors.grey.shade600;
  String _aiSuggestion = "Gathering calendar events and environmental data...";

  @override
  void initState() {
    super.initState();
    _selectedTop = _colors[0]; // Default: White
    _selectedBottom = _colors[3]; // Default: Navy

    _fetchSmartContext();
  }

  // THE SMART AI BRAIN (Professional Tone)
  Future<void> _fetchSmartContext() async {
    String todayEventText = "Your schedule is clear today.";

    // --- 1. GET TODAY'S EVENT FROM FIREBASE ---
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        String familyCode = userDoc.data()?['familyCode'] ?? '';

        if (familyCode.isNotEmpty) {
          String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

          var eventsSnapshot = await FirebaseFirestore.instance
              .collection('families')
              .doc(familyCode)
              .collection('events')
              .where('date', isEqualTo: todayStr)
              .limit(1)
              .get();

          if (eventsSnapshot.docs.isNotEmpty) {
            String eventTitle =
                eventsSnapshot.docs.first['title'] ?? 'a scheduled event';
            todayEventText = "You have '$eventTitle' on your agenda today.";
          }
        }
      }
    } catch (e) {
      debugPrint("Firebase Context Error: $e");
    }

    // --- 2. GET LIVE WEATHER ---
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];

        double temp = current['temperature'];
        int weatherCode = current['weathercode'];

        String condition = "Clear Conditions";
        IconData icon = Icons.wb_sunny_outlined;
        Color color = Colors.orange.shade600;
        String weatherAdvice = "A versatile wardrobe is suitable for today.";

        // Professional styling advice without emojis
        if (weatherCode <= 3) {
          condition = temp > 28 ? "Warm & Sunny" : "Clear & Pleasant";
          icon = Icons.light_mode_outlined;
          color = Colors.orange.shade500;
          weatherAdvice = temp > 28
              ? "Temperatures are reaching $temp°C. Light, breathable fabrics in Sky Blue, White, or Blush are highly recommended."
              : "A pleasant day at $temp°C. Navy or Beige combinations will provide a refined and comfortable look.";
        } else if (weatherCode >= 51 && weatherCode <= 67) {
          condition = "Rain & Showers";
          icon = Icons.water_drop_outlined;
          color = Colors.blue.shade700;
          weatherAdvice =
              "Expect precipitation today ($temp°C). Opt for practical, darker tones such as Black, Navy, or Maroon to conceal dampness.";
        } else if (weatherCode >= 71) {
          condition = "Cold & Freezing";
          icon = Icons.ac_unit_rounded;
          color = Colors.cyan.shade700;
          weatherAdvice =
              "Current temperature is low ($temp°C). Layering with deep colors like Black, Grey, or Olive is advisable for optimal thermal retention.";
        } else if (weatherCode >= 45 && weatherCode <= 48) {
          condition = "Overcast & Foggy";
          icon = Icons.cloud_outlined;
          color = Colors.blueGrey.shade600;
          weatherAdvice =
              "Visibility is low due to fog ($temp°C). Brighter top colors will ensure you stand out while maintaining elegance.";
        }

        // --- 3. COMBINE EVENT + WEATHER FOR FINAL OUTPUT ---
        if (mounted) {
          setState(() {
            _weatherCondition = condition;
            _weatherIcon = icon;
            _weatherColor = color;
            _aiSuggestion = "$todayEventText\n$weatherAdvice";
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherCondition = "Context Unavailable";
          _weatherIcon = Icons.sensors_off_rounded;
          _weatherColor = Colors.grey.shade500;
          _aiSuggestion =
              "$todayEventText\nUnable to retrieve localized weather data. Proceed with your preferred style.";
          _isLoadingData = false;
        });
      }
    }
  }

  // Professional Logic Output
  Map<String, dynamic> _analyzeOutfit(String top, String bottom) {
    if ((top == 'White' || top == 'Black' || top == 'Grey') && bottom != top) {
      return {
        'status': 'Perfect Match',
        'msg': 'Neutral colors blend seamlessly. A very sharp, executive look.',
        'color': const Color(0xFF34C759),
        'icon': Icons.check_circle_outline_rounded
      };
    }
    if ((top == 'Sky Blue' && bottom == 'Navy') ||
        (top == 'Blush' && bottom == 'Grey')) {
      return {
        'status': 'Stylist Choice',
        'msg': 'Highly professional and visually appealing combination.',
        'color': const Color(0xFF007AFF),
        'icon': Icons.verified_outlined
      };
    }
    if (top == 'Navy' && bottom == 'Beige') {
      return {
        'status': 'Classic & Elegant',
        'msg': 'A timeless business-casual aesthetic. Excellent choice.',
        'color': const Color(0xFF5856D6),
        'icon': Icons.diamond_outlined
      };
    }
    if ((top == 'Maroon' && bottom == 'Olive') ||
        (top == 'Olive' && bottom == 'Maroon')) {
      return {
        'status': 'Color Clash',
        'msg':
            'These distinct tones may conflict. Consider switching the bottom to Beige, Black, or Grey for balance.',
        'color': const Color(0xFFFF3B30),
        'icon': Icons.warning_amber_rounded
      };
    }
    if (top == 'Black' && bottom == 'Navy') {
      return {
        'status': 'Low Contrast',
        'msg':
            'Black and Navy together can appear unintentional. Try a lighter top to introduce contrast.',
        'color': const Color(0xFFFF9500),
        'icon': Icons.contrast_outlined
      };
    }
    if (top == bottom) {
      if (top == 'Black') {
        return {
          'status': 'All Black',
          'msg': 'Sleek and minimal. Ensure fabric textures vary for depth.',
          'color': const Color(0xFF8E8E93),
          'icon': Icons.nights_stay_outlined
        };
      }
      if (top == 'White') {
        return {
          'status': 'All White',
          'msg': 'Bold and clean. Ideal for daytime professional events.',
          'color': const Color(
              0xFF89CFF0), // Subtly changed to match standard palette feel
          'icon': Icons.cloud_queue_rounded
        };
      }
      return {
        'status': 'Monochrome',
        'msg': 'A uniform look conveys confidence. Well executed.',
        'color': const Color(0xFF5D6D7E),
        'icon': Icons.palette_outlined
      };
    }
    return {
      'status': 'Good to Go',
      'msg': 'A safe, balanced, and functional combination.',
      'color': const Color(0xFF34C759),
      'icon': Icons.thumb_up_alt_outlined
    };
  }

  @override
  Widget build(BuildContext context) {
    var result = _analyzeOutfit(_selectedTop['name'], _selectedBottom['name']);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Style Sync",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Live Weather & Calendar Context Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: Colors.black.withOpacity(0.02)),
                ),
                child: _isLoadingData
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(10.0),
                            child: CircularProgressIndicator(
                                color: Colors.blueGrey)))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: _weatherColor.withOpacity(0.12),
                                shape: BoxShape.circle),
                            child: Icon(_weatherIcon,
                                color: _weatherColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_weatherCondition,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(_aiSuggestion,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              // 2. Pro Outfit Visualizer
              Center(
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 25,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Visual with dynamic shadow for white shirts
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: _selectedTop['name'] == 'White'
                              ? [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      spreadRadius: 2)
                                ]
                              : [],
                        ),
                        child: Icon(Icons.checkroom_rounded,
                            size: 110, color: _selectedTop['color']),
                      ),
                      const SizedBox(height: 5),
                      // Bottom Visual
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 85,
                            decoration: BoxDecoration(
                                color: _selectedBottom['color'],
                                borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    topLeft: Radius.circular(4))),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 38,
                            height: 85,
                            decoration: BoxDecoration(
                                color: _selectedBottom['color'],
                                borderRadius: const BorderRadius.only(
                                    bottomRight: Radius.circular(8),
                                    topRight: Radius.circular(4))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 3. Minimalist Analysis Feedback
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: result['color'].withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: result['color'].withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(result['icon'], color: result['color'], size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result['status'],
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: result['color'])),
                          const SizedBox(height: 6),
                          Text(result['msg'],
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              // 4. Elegant Top Color Picker
              const Text("Select Top",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              SizedBox(
                height: 55,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    var colorItem = _colors[index];
                    bool isSelected = _selectedTop['name'] == colorItem['name'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTop = colorItem),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 16),
                        width: 55,
                        decoration: BoxDecoration(
                          color: colorItem['color'],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color:
                                          colorItem['color'].withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4))
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? Icon(Icons.done_rounded,
                                color: colorItem['color'] == Colors.white
                                    ? Colors.black87
                                    : Colors.white,
                                size: 22)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // 5. Elegant Bottom Color Picker
              const Text("Select Bottom",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              SizedBox(
                height: 55,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    var colorItem = _colors[index];
                    bool isSelected =
                        _selectedBottom['name'] == colorItem['name'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBottom = colorItem),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 16),
                        width: 55,
                        decoration: BoxDecoration(
                          color: colorItem['color'],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color:
                                          colorItem['color'].withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4))
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? Icon(Icons.done_rounded,
                                color: colorItem['color'] == Colors.white
                                    ? Colors.black87
                                    : Colors.white,
                                size: 22)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
