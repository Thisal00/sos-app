import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  //  Premium Royal Pastel Palette
  final List<Color> cardColors = [
    const Color(0xFFFFE5D9), // Peach
    const Color(0xFFE2ECE9), // Sage
    const Color(0xFFD0D1FF), // Lavender
    const Color(0xFFFFF4BD), // Lemon
    const Color(0xFFFFD1DC), // Rose
    const Color(0xFFB9F3FC), // Sky
  ];

  void _openEditor({Map<String, dynamic>? existingNote, String? docId}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DiaryEditorScreen(
          existingNote: existingNote,
          docId: docId,
          userUid: user?.uid ?? '',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _deleteEntry(String docId) {
    HapticFeedback.heavyImpact();
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('diary')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please login")));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            //  Royal Floating Header
            SliverAppBar(
              backgroundColor: const Color(0xFFFAFAFC),
              elevation: 0,
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text("Daily Journal",
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5)),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('diary')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.deepOrange)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        int colorIndex =
                            (data['colorIndex'] ?? index) % cardColors.length;

                        return _buildJournalCard(data, doc.id, colorIndex);
                      },
                      childCount: snapshot.data!.docs.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black87,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Entry",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        onPressed: () => _openEditor(),
      ),
    );
  }

  Widget _buildJournalCard(
      Map<String, dynamic> data, String id, int colorIndex) {
    DateTime date =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return GestureDetector(
      onTap: () => _openEditor(existingNote: data, docId: id),
      onLongPress: () {
        HapticFeedback.vibrate();
        _showDeleteDialog(id);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColors[colorIndex],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: cardColors[colorIndex].withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['mood'] ?? '😊',
                    style: const TextStyle(fontSize: 26)),
                Text(DateFormat('MMM dd').format(date),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              data['title'] ?? 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                data['content'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.fade,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("Delete Entry?",
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text(
              "This memory will be removed from your journal forever."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Keep it")),
            TextButton(
              onPressed: () {
                _deleteEntry(id);
                Navigator.pop(ctx);
              },
              child: const Text("Delete",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            // icones
            Icon(Icons.auto_awesome_rounded,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text("Your story starts here",
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

//  PREMIUM GLASS EDITOR SCREEN
class DiaryEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final String? docId;
  final String userUid;

  const DiaryEditorScreen(
      {super.key, this.existingNote, this.docId, required this.userUid});

  @override
  State<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends State<DiaryEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  String _selectedMood = '😊';
  final List<String> moods = ['😊', '🥰', '😌', '😔', '😡', '🤔', '😴', '🎉'];

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existingNote?['title'] ?? '');
    _contentCtrl =
        TextEditingController(text: widget.existingNote?['content'] ?? '');
    _selectedMood = widget.existingNote?['mood'] ?? '😊';
  }

  void _saveNote() {
    if (_titleCtrl.text.trim().isEmpty && _contentCtrl.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    var collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('diary');

    if (widget.docId == null) {
      collection.add({
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'mood': _selectedMood,
        'colorIndex': Random().nextInt(6),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      collection.doc(widget.docId).update({
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'mood': _selectedMood,
      });
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black, size: 28),
          onPressed: _saveNote,
        ),
        actions: [
          IconButton(
            onPressed: _saveNote,
            icon: const Icon(Icons.check_circle_rounded,
                color: Colors.deepOrange, size: 32),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Mood Row
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: moods.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedMood == moods[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMood = moods[index]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepOrange.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? Colors.deepOrange
                              : Colors.transparent),
                    ),
                    child: Center(
                        child: Text(moods[index],
                            style: const TextStyle(fontSize: 24))),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                    decoration: const InputDecoration(
                        hintText: "Title", border: InputBorder.none),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    style: const TextStyle(
                        fontSize: 19,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
