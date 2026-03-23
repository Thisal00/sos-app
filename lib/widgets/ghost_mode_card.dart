import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GhostModeCard extends StatelessWidget {
  const GhostModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const SizedBox.shrink();

        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isGhostMode = data['isGhostMode'] ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: isGhostMode ? Colors.purple.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color:
                    isGhostMode ? Colors.purple.shade200 : Colors.grey.shade100,
                width: 2),
            boxShadow: [
              BoxShadow(
                color: isGhostMode
                    ? Colors.purple.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGhostMode ? Colors.purple : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGhostMode
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: isGhostMode ? Colors.white : Colors.grey.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ghost Mode",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isGhostMode ? Colors.purple : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGhostMode
                          ? "Your location is hidden"
                          : "Hide location temporarily",
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isGhostMode,
                activeColor: Colors.purple,
                onChanged: (value) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'isGhostMode': value,
                    'status': value ? '👻 Ghost Mode' : '🟢 Online',
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
