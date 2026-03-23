import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Push Engine Import
import '../services/push_notification_service.dart';

class TasksScreen extends StatefulWidget {
  final String familyCode;
  const TasksScreen({super.key, required this.familyCode});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  //  Notification  Function
  Future<void> _sendTaskNotification(String taskTitle) async {
    try {
      String myName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'A family member';

      var usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('familyCode', isEqualTo: widget.familyCode)
          .get();

      for (var doc in usersSnap.docs) {
        if (doc.id != _myUid) {
          // Notification
          String? fcmToken = doc.data()['fcmToken'];
          if (fcmToken != null && fcmToken.isNotEmpty) {
            // Push
            PushNotificationService.sendPushMessage(
              targetFcmToken: fcmToken,
              title: "📌 New Task Added!",
              body: "$myName added a new task: $taskTitle",
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Task Push Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), //bg  view
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Family Tasks ",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              labelColor: Colors.deepOrange,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "All Tasks"),
                Tab(text: "My Tasks"),
                Tab(text: "Done"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskStream(filter: "All"),
          _buildTaskStream(filter: "My"),
          _buildTaskStream(filter: "Done"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Task",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddTaskModal(context),
      ),
    );
  }

  Widget _buildTaskStream({required String filter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyCode)
          .collection('tasks')
          .orderBy('dueDate', descending: false) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange));

        var tasks = snapshot.data!.docs;

        // Filtering Logic
        if (filter == "My") {
          tasks = tasks
              .where((doc) =>
                  doc['assignedTo'] == _myUid && doc['isDone'] == false)
              .toList();
        } else if (filter == "Done") {
          tasks = tasks.where((doc) => doc['isDone'] == true).toList();
        } else {
          tasks = tasks.where((doc) => doc['isDone'] == false).toList();
        }

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text("No tasks found!",
                    style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            var task = tasks[index];
            DateTime date = (task['dueDate'] as Timestamp).toDate();
            String dateLabel = _getDateLabel(date);

            // Header show (Today, Tomorrow...)
            bool showHeader = true;
            if (index > 0) {
              DateTime prevDate =
                  (tasks[index - 1]['dueDate'] as Timestamp).toDate();
              if (_getDateLabel(prevDate) == dateLabel) showHeader = false;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 10),
                    child: Text(dateLabel.toUpperCase(),
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                  ),
                _buildTaskCard(task),
              ],
            );
          },
        );
      },
    );
  }

  String _getDateLabel(DateTime date) {
    DateTime now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day)
      return "Today";
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1) return "Tomorrow";
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildTaskCard(QueryDocumentSnapshot task) {
    bool isUrgent = task['isUrgent'] ?? false;
    String title = task['title'];
    String subtitle = task['description'] ?? "";
    String assignedName = task['assignedName'] ?? "Family";
    Timestamp time = task['dueDate'];
    String timeStr = DateFormat('h:mm a').format(time.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Task Details Popup (Optional)
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                //  Checkbox Circle
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: task['isDone'],
                    shape: const CircleBorder(),
                    activeColor: Colors.green,
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                    onChanged: (val) {
                      task.reference.update({'isDone': val});
                    },
                  ),
                ),
                const SizedBox(width: 12),

                //  Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: task['isDone']
                                ? TextDecoration.lineThrough
                                : null,
                            color:
                                task['isDone'] ? Colors.grey : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text("$timeStr • $subtitle",
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                //  Urgent Tag & Avatar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isUrgent && !task['isDone'])
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("URGENT",
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.shade50,
                      child: Text(assignedName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //  New & Improved Add Task Modal
  void _showAddTaskModal(BuildContext context) {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    bool isUrgent = false;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text("Add New Task ✨",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: "What needs to be done?",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.task_alt_rounded,
                        color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    hintText: "Location or Details (e.g. Keells)",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),

                // Date & Urgent Switch
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final DateTime? date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100));
                          if (date != null) {
                            final TimeOfDay? time = await showTimePicker(
                                context: context, initialTime: selectedTime);
                            if (time != null) {
                              setModalState(() {
                                selectedDate = date;
                                selectedTime = time;
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                  DateFormat('MMM d, h:mm a').format(DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      selectedTime.hour,
                                      selectedTime.minute)),
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      label: const Text("URGENT"),
                      selected: isUrgent,
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                          color: isUrgent ? Colors.red : Colors.black,
                          fontWeight: FontWeight.bold),
                      onSelected: (val) => setModalState(() => isUrgent = val),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: () async {
                      if (titleCtrl.text.isNotEmpty) {
                        // Create Due Date
                        DateTime due = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute);

                        // 1. Firebase date save
                        await FirebaseFirestore.instance
                            .collection('families')
                            .doc(widget.familyCode)
                            .collection('tasks')
                            .add({
                          'title': titleCtrl.text,
                          'description': descCtrl.text,
                          'isDone': false,
                          'isUrgent': isUrgent,
                          'dueDate': Timestamp.fromDate(due),
                          'assignedTo': _myUid,
                          'assignedName':
                              FirebaseAuth.instance.currentUser?.displayName ??
                                  "Me",
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // Push Notification
                        _sendTaskNotification(titleCtrl.text);

                        //  Modal
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text("Create Task 🚀",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
