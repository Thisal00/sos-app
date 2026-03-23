import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

// Services
import '/services/weather_service.dart';

// Widgets Imports
import '../../widgets/sos_button.dart'; //  SOS Button
import '../../widgets/ghost_mode_card.dart';
import '../../widgets/family_card.dart';
import '../../widgets/family_member_list.dart';

// Screens Imports
import '../create_family_screen.dart';
import '../join_family_screen.dart';
import '../trusted_contacts_screen.dart';
import '../member_details_screen.dart';
import '../emergency_support_screen.dart';
import '../tasks/family_calendar_screen.dart';
import '../optimize_battery.dart';
import '../auth/login_screen.dart';
import '../fake_call_screen.dart';
import '../chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  String _currentAddress = "Locating nearby area...";
  int _todayTasksCount = 0;
  String _myFamilyCode = "";

  final Set<String> _alertedSOSUsers = {};
  final Set<String> _alertedBatteryUsers = {};
  final List<String> _dismissedAlertIds = [];

  StreamSubscription? _sosSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _tasksSubscription;

  @override
  void initState() {
    super.initState();
    _checkIfUserExists();
    _getCurrentLocationAddr();
    _startListeningForAlerts();
    _fetchTodayTasks();
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _batterySubscription?.cancel();
    _tasksSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkIfUserExists() async {
    if (user == null) return;
    var userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    var doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'name': user!.displayName ?? 'Family Member',
        'email': user!.email ?? '',
        'familyCode': '',
        'phone': user!.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isSOS': false, // Ensure SOS is false initially
      });
    }
  }

  void _startListeningForAlerts() async {
    if (user == null) return;
    DocumentSnapshot myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (myDoc.exists && myDoc.data() != null) {
      String code = (myDoc.data() as Map<String, dynamic>)['familyCode'] ?? '';

      if (code.isNotEmpty) {
        if (mounted) setState(() => _myFamilyCode = code);

        _sosSubscription = FirebaseFirestore.instance
            .collection('users')
            .where('familyCode', isEqualTo: code)
            .where('isSOS', isEqualTo: true)
            .snapshots()
            .listen((snapshot) {
          for (var doc in snapshot.docs) {
            String victimUid = doc.id;
            if (victimUid != user!.uid) {
              if (!_alertedSOSUsers.contains(victimUid)) {
                _alertedSOSUsers.add(victimUid);
                _showAlertDialog(
                    title: "EMERGENCY SOS",
                    message:
                        "${doc['name']} has triggered an SOS Alert! They need help.",
                    color: Colors.redAccent.shade700,
                    icon: Icons.warning_amber_rounded,
                    uid: victimUid,
                    victimData: doc.data(),
                    isSOS: true);
              }
            }
          }
        });

        _batterySubscription = FirebaseFirestore.instance
            .collection('batteryAlerts')
            .where('familyCode', isEqualTo: code)
            .snapshots()
            .listen((snapshot) {
          for (var doc in snapshot.docs) {
            var data = doc.data();
            String alertUid = data['uid'];
            if (alertUid != user!.uid) {
              Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
              if (DateTime.now().difference(timestamp.toDate()).inHours < 1) {
                if (!_alertedBatteryUsers.contains(doc.id)) {
                  _alertedBatteryUsers.add(doc.id);
                  _showAlertDialog(
                      title: "LOW BATTERY",
                      message:
                          "${data['name']}'s battery is critically low (${data['battery']}%).",
                      color: Colors.orange.shade800,
                      icon: Icons.battery_alert_rounded,
                      uid: alertUid,
                      victimData: data,
                      isSOS: false);
                }
              }
            }
          }
        });
      }
    }
  }

  void _showAlertDialog(
      {required String title,
      required String message,
      required Color color,
      required IconData icon,
      required String uid,
      required Map<String, dynamic> victimData,
      required bool isSOS}) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: color.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Column(
            children: [
              Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 50)),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
            ],
          ),
          content: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () {
                Navigator.pop(context);
                if (isSOS) _alertedSOSUsers.remove(uid);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MemberDetailsScreen(
                            userData: victimData, userId: uid)));
              },
              child: const Text("Track Location",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  void _fetchTodayTasks() async {
    if (user == null) return;
    DocumentSnapshot myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (myDoc.exists) {
      String familyCode =
          (myDoc.data() as Map<String, dynamic>)['familyCode'] ?? '';
      if (familyCode.isNotEmpty) {
        _tasksSubscription = FirebaseFirestore.instance
            .collection('families')
            .doc(familyCode)
            .collection('events')
            .where('date',
                isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
            .snapshots()
            .listen((snapshot) {
          if (mounted) setState(() => _todayTasksCount = snapshot.docs.length);
        });
      }
    }
  }

  String _getGreetingText() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon() {
    var hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.nights_stay_rounded;
  }

  Future<void> _getCurrentLocationAddr() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          _currentAddress =
              "${placemarks[0].street ?? 'Unknown'}, ${placemarks[0].locality ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Location Unavailable");
    }
  }

  void _triggerFakeCall() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [
          Icon(Icons.call_received_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text("Incoming call in 3 seconds...")
        ]),
        backgroundColor: Colors.indigo.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted)
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const FakeCallScreen(
                    callerName: "Mom", callerRole: "Mobile")));
    });
  }

  void _showNotificationCenter() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(40))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Alerts & Updates",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                letterSpacing: -0.5)),
                        IconButton(
                          icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.grey, size: 20)),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: _myFamilyCode.isEmpty
                          ? Center(
                              child: Text("Join a family to view alerts.",
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500)))
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('families')
                                  .doc(_myFamilyCode)
                                  .collection('alerts')
                                  .orderBy('timestamp', descending: true)
                                  .limit(20)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  return const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.deepOrange));
                                var alerts = (snapshot.data?.docs ?? [])
                                    .where((doc) =>
                                        !_dismissedAlertIds.contains(doc.id))
                                    .toList();
                                if (alerts.isEmpty) {
                                  return Center(
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                        Icon(Icons.check_circle_outline_rounded,
                                            size: 70,
                                            color: Colors.green.shade200),
                                        const SizedBox(height: 15),
                                        Text("You're all caught up!",
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600))
                                      ]));
                                }
                                return ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: alerts.length,
                                  itemBuilder: (context, index) {
                                    var doc = alerts[index];
                                    var data =
                                        doc.data() as Map<String, dynamic>;
                                    bool isSpeed = data['type'] == 'speed';
                                    return Dismissible(
                                      key: Key(doc.id),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (direction) {
                                        setSheetState(() =>
                                            _dismissedAlertIds.add(doc.id));
                                        HapticFeedback.mediumImpact();
                                      },
                                      background: Container(
                                          alignment: Alignment.centerRight,
                                          margin:
                                              const EdgeInsets.only(bottom: 15),
                                          padding:
                                              const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.8),
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          child: const Icon(
                                              Icons.delete_sweep_rounded,
                                              color: Colors.white,
                                              size: 28)),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 15),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: isSpeed
                                                    ? Colors.indigo.shade50
                                                    : Colors.orange.shade50,
                                                width: 2)),
                                        child: Row(
                                          children: [
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: isSpeed
                                                        ? Colors.indigo.shade50
                                                        : Colors.orange.shade50,
                                                    shape: BoxShape.circle),
                                                child: Icon(
                                                    isSpeed
                                                        ? Icons.speed_rounded
                                                        : Icons
                                                            .battery_alert_rounded,
                                                    color: isSpeed
                                                        ? Colors.indigo
                                                        : Colors.orange,
                                                    size: 20)),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      isSpeed
                                                          ? "${data['name']} Over-Speeding"
                                                          : "${data['name']}'s Battery Low",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 15,
                                                          color:
                                                              Colors.black87)),
                                                  Text(
                                                      isSpeed
                                                          ? "Driving at ${double.parse((data['value'] ?? 0).toString()).toStringAsFixed(0)} km/h"
                                                          : "Battery level at ${data['value']}%",
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey.shade700,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopChatBanner() {
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          String code =
              (snapshot.data!.data() as Map<String, dynamic>)['familyCode'] ??
                  "";
          if (code.isNotEmpty) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(familyCode: code)));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.forum_rounded,
                            color: Colors.white, size: 30)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text("Family Group Chat",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 5),
                          Text("Tap to open secure messenger",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))
                        ])),
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 16)),
                  ],
                ),
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //  OVERFLOW FIXED HEADER
              Container(
                margin: const EdgeInsets.only(top: 5, bottom: 25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.08),
                        blurRadius: 25,
                        offset: const Offset(0, 10))
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Avatar & Name Column (Wrapped in Expanded to fix pixel overflow)
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [
                                Colors.deepOrange,
                                Colors.orangeAccent
                              ]),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.deepOrange.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Text(
                                  user?.displayName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      "U",
                                  style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getGreetingIcon(),
                                        size: 12, color: Colors.deepOrange),
                                    const SizedBox(width: 4),
                                    Text(_getGreetingText(),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Text won't overflow anymore, it will add "..."
                                Text(user?.displayName ?? "User",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.heavyImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("🌤️ Fetching Weather Alert..."),
                                    backgroundColor: Colors.blue,
                                    behavior: SnackBarBehavior.floating));
                            await WeatherService.checkAndSendMorningAlert(
                                isTesting: true);
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.cloud_sync_rounded,
                                color: Colors.blue, size: 20),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showNotificationCenter,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: Colors.deepOrange.shade50,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.deepOrange,
                                size: 20),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              _buildTopChatBanner(),

              //  THE SEPARATE SOS BUTTON CALL (SMS Logic + New UI is in here)
              const SOSButton(),
              const SizedBox(height: 25),

              //  PRO GRID
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.0,
                children: [
                  _buildRoyalGridCard(
                      title: "Escape",
                      subtitle: "Simulate Call",
                      icon: Icons.phone_in_talk_rounded,
                      color: Colors.indigo,
                      onTap: _triggerFakeCall),
                  _buildRoyalGridCard(
                      title: "Emergency",
                      subtitle: "Direct Lines",
                      icon: Icons.health_and_safety_rounded,
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EmergencySupportScreen()))),
                  _buildRoyalGridCard(
                      title: "Optimizer",
                      subtitle: "Background Fix",
                      icon: Icons.bolt_rounded,
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BatteryOptimizationScreen()))),
                  _buildRoyalGridCard(
                      title: "Calendar",
                      subtitle: "$_todayTasksCount Events",
                      icon: Icons.calendar_month_rounded,
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FamilyCalendarScreen()))),
                ],
              ),
              const SizedBox(height: 25),

              //  LOCATION & GHOST MODE
              const Text("Privacy & Status",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: -0.5)),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white,
                    Colors.blue.shade50.withOpacity(0.5)
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                        padding: const EdgeInsets.all(15),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 10)
                            ]),
                        child: const Icon(Icons.my_location_rounded,
                            color: Colors.blueAccent, size: 24)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Current Location",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(_currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const GhostModeCard(),
              const SizedBox(height: 35),

              //  FAMILY SECTION
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data.containsKey('familyCode') &&
                        data['familyCode'] != "") {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FamilyCard(familyCode: data['familyCode']),
                          const SizedBox(height: 35),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Family Circle",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: Colors.black87)),
                              InkWell(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const TrustedContactsScreen())),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade50,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(children: const [
                                    Icon(Icons.admin_panel_settings_rounded,
                                        size: 16, color: Colors.deepOrange),
                                    SizedBox(width: 6),
                                    Text("Manage",
                                        style: TextStyle(
                                            color: Colors.deepOrange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800))
                                  ]),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          FamilyMemberList(familyCode: data['familyCode']),
                        ],
                      );
                    }
                  }
                  return _buildNoFamilyState();
                },
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoyalGridCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamilyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white,
            Colors.deepOrange.shade50.withOpacity(0.5)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.deepOrange.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 15))
          ]),
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  color: Colors.deepOrange.shade100.withOpacity(0.5),
                  shape: BoxShape.circle),
              child: const Icon(Icons.shield_rounded,
                  size: 60, color: Colors.deepOrange)),
          const SizedBox(height: 25),
          const Text("Protect Your Loved Ones",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black87,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text(
              "Create or join a family group to enable real-time tracking, SOS alerts, and secure vault.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 35),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateFamilyScreen())),
                    icon: const Icon(Icons.add_moderator_rounded,
                        color: Colors.white, size: 20),
                    label: const Text("Create",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 10,
                        shadowColor: Colors.deepOrange.withOpacity(0.5)))),
            const SizedBox(width: 15),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const JoinFamilyScreen())),
                    icon: const Icon(Icons.login_rounded,
                        color: Colors.deepOrange, size: 20),
                    label: const Text("Join",
                        style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.deepOrange, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)))))
          ])
        ],
      ),
    );
  }
}
