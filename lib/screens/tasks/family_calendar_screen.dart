import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Push Engine  Import
import '/services/push_notification_service.dart';

class FamilyCalendarScreen extends StatefulWidget {
  const FamilyCalendarScreen({super.key});

  @override
  State<FamilyCalendarScreen> createState() => _FamilyCalendarScreenState();
}

class _FamilyCalendarScreenState extends State<FamilyCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _familyCode;
  String? _myName;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchFamilyDetails();
  }

  // family code
  Future<void> _fetchFamilyDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _familyCode = (doc.data() as Map<String, dynamic>)['familyCode'];
          _myName =
              (doc.data() as Map<String, dynamic>)['name'] ?? 'Family Member';
        });
      }
    }
  }

  //  Notification  Function
  Future<void> _sendEventNotification(String eventTitle) async {
    try {
      String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
      String senderName = _myName ?? "A family member";

      var usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('familyCode', isEqualTo: _familyCode)
          .get();

      for (var doc in usersSnap.docs) {
        if (doc.id != myUid) {
          //  Notification not come to me
          String? fcmToken = doc.data()['fcmToken'];
          if (fcmToken != null && fcmToken.isNotEmpty) {
            // Push  sent
            PushNotificationService.sendPushMessage(
              targetFcmToken: fcmToken,
              title: "📅 New Event Added!",
              body: "$senderName scheduled an event: $eventTitle",
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Event Push Error: $e");
    }
  }

  
  Future<void> _addEvent() async {
    if (_titleController.text.isEmpty || _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter both title and time!"),
          backgroundColor: Colors.red));
      return;
    }

    if (_familyCode != null && _familyCode!.isNotEmpty) {
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
      String eventTitle = _titleController.text;

      //  Firebase  Save
      await FirebaseFirestore.instance
          .collection('families')
          .doc(_familyCode)
          .collection('events')
          .add({
        'title': eventTitle,
        'time': _timeController.text,
        'date': dateKey,
        'creator': _myName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      //  Push Notification
      _sendEventNotification(eventTitle);

      _titleController.clear();
      _timeController.clear();
      if (mounted) {
        Navigator.pop(context); //
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Event Added Successfully! "),
            backgroundColor: Colors.green));
      }
    }
  }

  void _showAddEventDialog() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "Add Event for ${DateFormat('MMM dd').format(_selectedDay!)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: "Event Title (e.g. Birthday Party)",
                    prefixIcon: const Icon(Icons.event),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: "Time (e.g. 10:00 AM)",
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _addEvent,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    child: const Text("Save Event",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.calendar_month,
                    color: Colors.deepOrange, size: 20)),
            const SizedBox(width: 10),
            const Text("Family Calendar",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Widget
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 10)
                ]),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                    color: Colors.blue.shade100, shape: BoxShape.circle),
                selectedDecoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showAddEventDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Event",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Scheduled Events",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(DateFormat('MMMM dd').format(_selectedDay!),
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          //  FIREBASE EVENTS LIST
          Expanded(
            child: _familyCode == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('families')
                        .doc(_familyCode)
                        .collection('events')
                        .where('date',
                            isEqualTo:
                                DateFormat('yyyy-MM-dd').format(_selectedDay!))
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text("No events scheduled for this day.",
                                style: TextStyle(color: Colors.grey)));
                      }

                      // Sort Locally in Dart
                      var events = snapshot.data!.docs.toList();
                      events.sort((a, b) {
                        Timestamp tA = a['timestamp'] ?? Timestamp.now();
                        Timestamp tB = b['timestamp'] ?? Timestamp.now();
                        return tA.compareTo(tB);
                      });

                      List<Color> colors = [
                        Colors.orange,
                        Colors.green,
                        Colors.purple,
                        Colors.blue
                      ];
                      List<IconData> icons = [
                        Icons.star,
                        Icons.cake,
                        Icons.celebration,
                        Icons.event
                      ];

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          var data =
                              events[index].data() as Map<String, dynamic>;
                          Color tileColor = colors[index % colors.length];
                          IconData tileIcon = icons[index % icons.length];

                          String creatorName = data['creator'] ?? "?";
                          String initial = creatorName.isNotEmpty
                              ? creatorName[0].toUpperCase()
                              : "?";

                          return _buildEventTile(
                            title: data['title'] ?? "Family Event",
                            time: data['time'] ?? "All Day",
                            icon: tileIcon,
                            color: tileColor,
                            avatarInitial: initial,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(
      {required String title,
      required String time,
      required IconData icon,
      required Color color,
      required String avatarInitial}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade100, blurRadius: 5, spreadRadius: 1)
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 5),
                Text(time,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: Text(avatarInitial,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }
}
