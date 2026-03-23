import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SecurityLogScreen extends StatelessWidget {
  final String familyCode;

  const SecurityLogScreen({super.key, required this.familyCode});

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
          "Security Audit Logs",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Firebase   log in
        stream: FirebaseFirestore.instance
            .collection('families')
            .doc(familyCode)
            .collection('security_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          //  Error Handling  (App to Crash )
          if (snapshot.hasError) {
            return const Center(
              child: Text("Something went wrong loading logs.",
                  style: TextStyle(color: Colors.red, fontSize: 16)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("No security logs found.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          var logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              var data = logs[index].data() as Map<String, dynamic>;
              String event = data['event'] ?? "Unknown Event";
              String user = data['user'] ?? "Unknown User";
              String status = data['status'] ?? "Info";

              // time  steup
              Timestamp? timestamp = data['timestamp'];
              String timeString = "Just now";
              if (timestamp != null) {
                DateTime date = timestamp.toDate();
                timeString = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border(
                      left: BorderSide(
                          color:
                              status == 'Success' ? Colors.green : Colors.red,
                          width: 5)),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: status == 'Success'
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        status == 'Success'
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: status == 'Success' ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Accessed by: $user",
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Text(timeString,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

