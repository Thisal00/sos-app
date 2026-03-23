import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

// THE FIX: Weather Service
import '../services/weather_service.dart';

// Screens
import 'dashboard/dashboard_screen.dart';
import 'map_screen.dart';
import 'community_screen.dart'; // This is Activity Insights
import 'profile_screen.dart';
import 'safe_zones_screen.dart';

// Features
import 'tasks_screen.dart';
import 'finance_screen.dart';
import 'chat_screen.dart';
import 'diary_screen.dart';
import 'family_vault_screen.dart';
import 'wardrobe_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _familyCode = "";
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .snapshots();

    _saveDeviceToken();
    _triggerWeatherOnStartup();
  }

  Future<void> _triggerWeatherOnStartup() async {
    try {
      await WeatherService.checkAndSendMorningAlert(isTesting: false);
    } catch (e) {
      debugPrint("Weather Check Error: $e");
    }
  }

  Future<void> _saveDeviceToken() async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && _currentUserId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .set({
          'fcmToken': fcmToken,
        }, SetOptions(merge: true));
        debugPrint("✅ FCM Token Saved: $fcmToken");
      }
    } catch (e) {
      debugPrint("❌ Failed to save token: $e");
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          _familyCode = data['familyCode'] ?? "";
        }

        // State preserving IndexedStack (Keeps Map from reloading)
        final List<Widget> pages = [
          const DashboardScreen(),
          MapScreen(familyCode: _familyCode),
          _familyCode.isNotEmpty
              ? ChatScreen(familyCode: _familyCode)
              : _buildNoFamilyWarning(),
          const ProfileScreen(),
        ];

        return Scaffold(
          extendBody: true, //  Keeps Full Screen look
          backgroundColor: const Color(0xFFFAFAFC),
          body: Stack(
            children: [
              // 1. MAIN BACKGROUND SCREENS
              IndexedStack(
                index: _currentIndex,
                children: pages,
              ),

              // 2. FLOATING GLASS NAVIGATION BAR
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin:
                        const EdgeInsets.only(bottom: 25, left: 20, right: 20),
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85), // Glass Effect
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(Icons.grid_view_rounded, 0),
                            _buildNavItem(Icons.map_rounded, 1),

                            //  The Center Premium Add Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                _showProQuickActions(context, _familyCode);
                              },
                              child: Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.deepOrange,
                                      Colors.orangeAccent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepOrange.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.add_rounded,
                                    size: 32, color: Colors.white),
                              ),
                            ),

                            _buildNavItem(Icons.chat_bubble_rounded, 2),
                            _buildNavItem(Icons.person_2_rounded, 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper for Glass Nav Items with Smooth Animation ---
  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepOrange.withOpacity(0.12)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Icon(
            icon,
            size: 26,
            color: isSelected ? Colors.deepOrange : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  // --- Safe Fallback Screen if NO Family is Joined ---
  Widget _buildNoFamilyWarning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("No Family Connected",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          Text("Join or create a family circle\nto start chatting.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  //  THE PRO QUICK ACTIONS MENU ---
  void _showProQuickActions(BuildContext context, String code) {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Access Denied: Join a family circle first."),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding:
              const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // Frosted white look
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: SafeArea(
            //  Fixed bottom cutoff issue
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 25),
                const Text("Quick Actions",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.5)),
                const SizedBox(height: 35),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 25,
                  runSpacing: 25,
                  children: [
                    _buildActionBubble(
                        context,
                        Icons.insights_rounded,
                        "Insights",
                        Colors.blue,
                        () => _navTo(context, const CommunityScreen())),
                    _buildActionBubble(
                        context,
                        Icons.assignment_rounded,
                        "Tasks",
                        Colors.green,
                        () => _navTo(context, TasksScreen(familyCode: code))),
                    _buildActionBubble(
                        context,
                        Icons.account_balance_wallet_rounded,
                        "Finance",
                        Colors.orange,
                        () => _navTo(context, const FinanceScreen())),
                    _buildActionBubble(
                        context,
                        Icons.lock_rounded,
                        "Vault",
                        Colors.indigo,
                        () => _navTo(context, const FamilyVaultScreen())),
                    _buildActionBubble(
                        context,
                        Icons.menu_book_rounded,
                        "Diary",
                        Colors.pink,
                        () => _navTo(context, const DiaryScreen())),
                    _buildActionBubble(
                        context,
                        Icons.location_on_rounded,
                        "Zones",
                        Colors.teal,
                        () =>
                            _navTo(context, SafeZonesScreen(familyCode: code))),
                    _buildActionBubble(
                        context,
                        Icons.checkroom_rounded,
                        "Wardrobe",
                        Colors.purple,
                        () => _navTo(context, const WardrobeScreen())),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // menu close
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // --- Premium Bubble Widget for Quick Actions ---
  Widget _buildActionBubble(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withOpacity(0.2), width: 1.5)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
