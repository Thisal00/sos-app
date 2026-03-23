import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ඔයාගේ Main Screen එක තියෙන තැන හරියට import කරගන්න
// import 'main_screen.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  bool _isLocationGranted = false;
  bool _isBatteryIgnored = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // දැනට තියෙන Permissions මොනවද කියලා Check කරනවා
  Future<void> _checkPermissions() async {
    bool locGranted = await Permission.locationAlways.isGranted;
    bool batIgnored = await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {
        _isLocationGranted = locGranted;
        _isBatteryIgnored = batIgnored;
      });
    }
  }

  // 1. Location Permission ඉල්ලන Function එක
  Future<void> _requestLocation() async {
    // Android 11+ වල මුලින්ම Foreground ඉල්ලලා ඉන්න ඕනේ
    var status = await Permission.location.request();
    if (status.isGranted) {
      var alwaysStatus = await Permission.locationAlways.request();
      setState(() {
        _isLocationGranted = alwaysStatus.isGranted;
      });
    } else {
      await openAppSettings();
    }
    _checkPermissions(); // ආයේ චෙක් කරනවා
  }

  // 2. Battery Permission ඉල්ලන Function එක
  Future<void> _requestBattery() async {
    var status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _isBatteryIgnored = status.isGranted;
    });

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Please select 'Unrestricted' in battery settings manually."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await openAppSettings();
    }
    _checkPermissions();
  }

  // සේරම හරි නම් ඉස්සරහට යන Function එක
  void _finishSetup() async {
    if (_isLocationGranted && _isBatteryIgnored) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_battery_optimized_setup_done', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Protection Activated Successfully! 🛡️"),
            backgroundColor: Colors.green,
          ),
        );
        // මෙතනින් Main Screen එකට යන්න (කමෙන්ට් එක අයින් කරලා හරියට දෙන්න)
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please grant all permissions to continue."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Background Optimization"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "Keep Protection Active 🛡️",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "To ensure 'Shake to SOS' and Location Tracking works even when your phone is locked in your pocket, please allow the following permissions.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 30),

              // 1. Location Always Request Card
              _buildPermissionCard(
                title: "Always Allow Location",
                subtitle: "Needed for Live Tracking in background.",
                icon: Icons.location_on_rounded,
                isGranted: _isLocationGranted,
                onTap: _requestLocation,
              ),

              const SizedBox(height: 15),

              // 2. Battery Optimization Request Card
              _buildPermissionCard(
                title: "Allow Unrestricted Battery",
                subtitle: "Prevents Android from killing the app.",
                icon: Icons.battery_saver_rounded,
                isGranted: _isBatteryIgnored,
                onTap: _requestBattery,
              ),

              const Spacer(),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLocationGranted && _isBatteryIgnored)
                        ? Colors.green
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: (_isLocationGranted && _isBatteryIgnored)
                      ? _finishSetup
                      : null,
                  child: Text(
                    (_isLocationGranted && _isBatteryIgnored)
                        ? "Complete Setup & Continue"
                        : "Complete Steps Above",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Permission අහන ලස්සන Card එකක්
  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isGranted ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.shade100 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isGranted ? Colors.green : Colors.grey.shade600,
                  size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isGranted ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              isGranted
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: isGranted ? Colors.green : Colors.grey.shade400,
              size: isGranted ? 28 : 18,
            ),
          ],
        ),
      ),
    );
  }
}
