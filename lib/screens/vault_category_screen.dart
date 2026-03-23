import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/services.dart';

class VaultCategoryScreen extends StatefulWidget {
  final String categoryName;
  final String familyCode;

  const VaultCategoryScreen({
    super.key,
    required this.categoryName,
    required this.familyCode,
  });

  @override
  State<VaultCategoryScreen> createState() => _VaultCategoryScreenState();
}

class _VaultCategoryScreenState extends State<VaultCategoryScreen> {
  //  PRO FIX 1 100% Deterministic Key & IV
  static final _key = encrypt.Key.fromUtf8('EnivacTechFamilyVaultSecretKey32');
  static final _iv = encrypt.IV.fromUtf8('EnivacFamilyIV16');

  //  PRO FIX 2: Encrypter
  // CBC Mode
  static final _encrypter =
      encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));

  //  Encrypt කරන Function එක
  String _encryptData(String text) {
    if (text.isEmpty) return "";
    try {
      final encrypted = _encrypter.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print("Encryption Error: $e");
      return text;
    }
  }

  //  Decrypt Function
  String _decryptData(String encryptedText) {
    if (encryptedText.isEmpty) return "";
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      print("Decryption Error: $e"); // Debug
      return "Decryption Failed";
    }
  }

  //  Add Bottom Sheet
  void _showAddDataSheet() {
    TextEditingController titleController = TextEditingController();
    TextEditingController valueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.green),
                  const SizedBox(width: 10),
                  Text("Add to ${widget.categoryName}",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              const Text("Data will be AES-256 encrypted before saving.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Title (e.g., BOC Account, Netflix)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: "Secret Value (Account No, Password, etc.)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        valueController.text.isEmpty) return;

                    //  Encrypting Data Before Upload
                    String encryptedTitle = _encryptData(titleController.text);
                    String encryptedValue = _encryptData(valueController.text);

                    await FirebaseFirestore.instance
                        .collection('families')
                        .doc(widget.familyCode)
                        .collection('vault')
                        .doc(widget.categoryName)
                        .collection('items')
                        .add({
                      'title': encryptedTitle,
                      'value': encryptedValue,
                      'addedBy':
                          FirebaseAuth.instance.currentUser?.displayName ??
                              "Member",
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Encrypt & Save ",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
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
        title: Text(widget.categoryName,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDataSheet,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: const Text("Add Secure Data",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyCode)
            .collection('vault')
            .doc(widget.categoryName)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("No secure data found.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          var items = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              var data = items[index].data() as Map<String, dynamic>;

              String decryptedTitle = _decryptData(data['title'] ?? "");
              String decryptedValue = _decryptData(data['value'] ?? "");
              String addedBy = data['addedBy'] ?? "Member";

              return VaultItemCard(
                title: decryptedTitle,
                value: decryptedValue,
                addedBy: addedBy,
              );
            },
          );
        },
      ),
    );
  }
}

//  PRO FEATURE: "Tap to Reveal" Card Widget
class VaultItemCard extends StatefulWidget {
  final String title;
  final String value;
  final String addedBy;

  const VaultItemCard({
    super.key,
    required this.title,
    required this.value,
    required this.addedBy,
  });

  @override
  State<VaultItemCard> createState() => _VaultItemCardState();
}

class _VaultItemCardState extends State<VaultItemCard> {
  bool _isHidden = true; //  Value

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.key_rounded, color: Colors.green),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87)),
                const SizedBox(height: 5),
                //  Hide/Show Logic
                Text(
                  _isHidden ? "••••••••••••" : widget.value,
                  style: TextStyle(
                      fontSize: _isHidden ? 24 : 18,
                      color: _isHidden ? Colors.grey : Colors.indigo,
                      fontWeight: FontWeight.w600,
                      letterSpacing: _isHidden ? 2.0 : 1.2),
                ),
                const SizedBox(height: 8),
                Text("Added by ${widget.addedBy}",
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          // Show/Hide Button
          IconButton(
            onPressed: () {
              setState(() {
                _isHidden = !_isHidden;
              });
            },
            icon: Icon(
              _isHidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.grey.shade600,
            ),
          ),
          //  Copy Button
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Copied to clipboard! 📋"),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

