import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

// Screens
import 'auth/login_screen.dart';
import 'family_vault_screen.dart';
import 'safe_zones_screen.dart';
import 'location_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;

  //  Logout Function
  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text("Are you sure you want to log out from FamilyLink?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Log Out",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  //  Leave Family Function (Pro Feature)
  Future<void> _leaveFamily() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Leave Family?",
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
            "If you leave, you won't be able to see family locations or alerts until you rejoin."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (currentUser != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .update({
                  'familyCode': '', // Remove the code
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("You have left the family."),
                        backgroundColor: Colors.orange),
                  );
                }
              }
            },
            child: const Text("Leave",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  //  Toggle Settings Update
  Future<void> _updateToggle(String field, bool value) async {
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({field: value});
    }
  }

  //  Edit Profile Dialog
  void _editProfileDialog(String currentName, String currentPhone) {
    TextEditingController nameController =
        TextEditingController(text: currentName);
    TextEditingController phoneController =
        TextEditingController(text: currentPhone);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: const Icon(Icons.person_rounded,
                      color: Colors.deepOrange),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon:
                      const Icon(Icons.phone_rounded, color: Colors.deepOrange),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty) return;

                      setDialogState(() => isSaving = true);

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser!.uid)
                          .update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Profile Updated! ✅"),
                              backgroundColor: Colors.green),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Save",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  //  Base64 Image Upload
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
      maxWidth: 200,
      maxHeight: 200,
    );

    if (image != null && currentUser != null) {
      setState(() => _isUploading = true);
      try {
        File file = File(image.path);
        Uint8List imageBytes = await file.readAsBytes();
        String base64String = base64Encode(imageBytes);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'profilePicBase64': base64String});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Profile Picture Updated! 📸"),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to upload: $e"),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Center(child: Text("Not Logged In"));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.deepOrange));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String name = userData['name'] ?? "Unknown User";
          String email = userData['email'] ?? currentUser!.email ?? "";
          String phone = userData['phone'] ?? "No Phone Number";
          String familyCode = userData['familyCode'] ?? "";
          bool isGhostMode = userData['ghostMode'] ?? false;
          bool isLocationOn = userData['locationShared'] ?? true;
          String? profilePicBase64 = userData['profilePicBase64'];

          bool hasFamily = familyCode.isNotEmpty;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- Premium Header ---
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(
                      top: 60, bottom: 30, left: 20, right: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepOrange, Colors.orangeAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("My Profile",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.white),
                            onPressed: () => _editProfileDialog(name, phone),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.deepOrange.shade100,
                                backgroundImage:
                                    profilePicBase64 != null && !_isUploading
                                        ? MemoryImage(
                                            base64Decode(profilePicBase64))
                                        : null,
                                child: _isUploading
                                    ? const CircularProgressIndicator(
                                        color: Colors.deepOrange)
                                    : (profilePicBase64 == null
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange))
                                        : null),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(email,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Family Code & Phone Info ---
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: hasFamily
                                  ? () {
                                      Clipboard.setData(
                                          ClipboardData(text: familyCode));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("Family Code Copied!"),
                                            backgroundColor: Colors.green),
                                      );
                                    }
                                  : null,
                              child: _buildInfoCard(
                                Icons.family_restroom_rounded,
                                "Family Code",
                                hasFamily ? familyCode : "None",
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildInfoCard(Icons.phone_rounded,
                                  "Phone", phone, Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 25),

                      const Text("Settings & Privacy",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 15),

                      _buildMenuCard(
                        children: [
                          _buildSwitchTile(
                            Icons.location_on_rounded,
                            "Share Location",
                            "Allow family to see your location",
                            Colors.green,
                            isLocationOn,
                            (val) => _updateToggle('locationShared', val),
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildSwitchTile(
                            Icons.visibility_off_rounded,
                            "Ghost Mode",
                            "Hide location temporarily",
                            Colors.indigo,
                            isGhostMode,
                            (val) => _updateToggle('ghostMode', val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text("Tools & Features",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 15),

                      _buildMenuCard(
                        children: [
                          _buildMenuTile(
                              Icons.shield_rounded,
                              "Family Vault",
                              "Access secure passwords & documents",
                              Colors.orange, () {
                            if (hasFamily) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const FamilyVaultScreen()));
                            } else {
                              _showNoFamilyError();
                            }
                          }),
                          const Divider(height: 1, indent: 60),
                          _buildMenuTile(Icons.map_rounded, "Safe Zones",
                              "Manage geofenced areas", Colors.teal, () {
                            if (hasFamily) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => SafeZonesScreen(
                                          familyCode: familyCode)));
                            } else {
                              _showNoFamilyError();
                            }
                          }),
                          const Divider(height: 1, indent: 60),
                          _buildMenuTile(
                              Icons.history_rounded,
                              "Location History",
                              "View your past routes",
                              Colors.blueGrey, () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const LocationHistoryScreen()));
                          }),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // --- Danger Zone (Leave Family & Logout) ---
                      if (hasFamily) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            onPressed: _leaveFamily,
                            icon: const Icon(Icons.exit_to_app_rounded,
                                color: Colors.orange),
                            label: const Text("Leave Family",
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              color: Colors.redAccent),
                          label: const Text("Log Out",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),

                      //  FIX: Nav Bar
                      const SizedBox(height: 120),
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

  void _showNoFamilyError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Please join a family first!"),
          backgroundColor: Colors.redAccent),
    );
  }

  // --- Helper Widgets ---
  Widget _buildInfoCard(
      IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 16, color: Colors.grey),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle,
      Color color, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepOrange,
        activeTrackColor: Colors.deepOrange.shade200,
      ),
    );
  }
}
