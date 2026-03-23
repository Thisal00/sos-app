import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'vault_category_screen.dart';
import 'security_log_screen.dart';

class FamilyVaultScreen extends StatefulWidget {
  const FamilyVaultScreen({super.key});

  @override
  State<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends State<FamilyVaultScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  //PRO FIX: Family Code
  String _myFamilyCode = "";

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  // Security Audit Log  Fingerprint / Face ID / PIN / Pattern Logic
  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
      });

      //  Security  (Biometrics or  PIN/Pattern)
      bool isSupported = await auth.isDeviceSupported();

      if (isSupported) {
        authenticated = await auth.authenticate(
          localizedReason: 'Scan Biometrics or enter PIN to unlock the Vault',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "⚠️ Your phone needs a Screen Lock (PIN/Pattern) to use the Vault!"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        authenticated = false;
      }

      //SECURITY FEATURE & OPTIMIZATION
      if (authenticated) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          // Database get  Variable
          _myFamilyCode = userDoc.data()?['familyCode'] ?? "";
          String userName = userDoc.data()?['name'] ?? "Unknown Member";

          if (_myFamilyCode.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('families')
                .doc(_myFamilyCode)
                .collection('security_logs')
                .add({
              'event': 'Vault Unlocked',
              'user': userName,
              'uid': user.uid,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'Success'
            });
          }
        }
      }
    } on PlatformException catch (e) {
      print("Auth Error: $e");
      authenticated = false;
    }

    if (!mounted) return;

    setState(() {
      _isAuthenticated = authenticated;
      _isAuthenticating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "Family Vault",
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
        ),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.indigo),
              onPressed: () {
                //  PRO FIX Database not sent  Save
                if (_myFamilyCode.isNotEmpty && mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SecurityLogScreen(familyCode: _myFamilyCode),
                      ));
                }
              },
            )
        ],
      ),
      body: _isAuthenticated ? _buildVaultContent() : _buildLockScreen(),
    );
  }

  Widget _buildLockScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded,
              size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text(
            "Vault is Locked",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Your sensitive family documents and accounts are protected by biometric/PIN security.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 40),
          _isAuthenticating
              ? const CircularProgressIndicator(color: Colors.blue)
              : ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.security_rounded,
                      color: Colors.white, size: 28),
                  label: const Text(
                    "Unlock Vault",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildVaultContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 40),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Vault Unlocked",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Your data is AES-256 encrypted and safe.",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Categories",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildCategoryCard("Finance",
                    Icons.account_balance_wallet_rounded, Colors.orange),
                _buildCategoryCard(
                    "Utilities", Icons.lightbulb_rounded, Colors.amber),
                _buildCategoryCard(
                    "Identity", Icons.badge_rounded, Colors.blue),
                _buildCategoryCard(
                    "Properties", Icons.home_rounded, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // PRO FIXFirebase Call not sent lood  it
        if (_myFamilyCode.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VaultCategoryScreen(
                  categoryName: title, familyCode: _myFamilyCode),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 35),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

