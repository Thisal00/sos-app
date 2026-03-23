import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyCard extends StatelessWidget {
  final String familyCode; //

  const FamilyCard({
    super.key,
    required this.familyCode, // Constructor erro   end  to
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .where('inviteCode', isEqualTo: familyCode)
          .snapshots(),
      builder: (context, snapshot) {
        String familyName = "My Family";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          familyName = data['name'] ?? "My Family";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.home_filled,
                              color: Colors.white.withOpacity(0.8), size: 16),
                          const SizedBox(width: 5),
                          const Text("Current Family",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(familyName,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.verified_user_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("INVITE CODE",
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(familyCode,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: familyCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Copied! ✅"),
                                backgroundColor: Colors.teal));
                      },
                      child: const Icon(Icons.copy_rounded, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
