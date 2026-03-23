import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Push Engine Import
import '../services/push_notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String familyCode;
  const ChatScreen({super.key, required this.familyCode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Audio Player Variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  bool _isAudioLoading = false;

  @override
  void initState() {
    super.initState();
    // Audio button state listener
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
  }

  // normal text msg sent
  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Family Member";

    // 1. Database msg Save
    await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyCode)
        .collection('chat')
        .add({
      'text': text,
      'senderId': _myUid,
      'senderName': myName,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // push notfi
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('familyCode', isEqualTo: widget.familyCode)
          .get();

      for (var doc in usersSnapshot.docs) {
        if (doc.id != _myUid) {
          final data = doc.data();
          final fcmToken = data['fcmToken'];

          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            await PushNotificationService.sendPushMessage(
              targetFcmToken: fcmToken,
              title: "💬 New message from $myName",
              body: text,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Push Notification Error in Chat: $e");
    }
  }

  // Base64 Audio Play Function for SOS
  Future<void> _playAudio(String base64Data) async {
    if (_currentlyPlayingUrl == base64Data && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        setState(() => _isAudioLoading = true);

        Uint8List audioBytes = base64Decode(base64Data);

        final dir = await getTemporaryDirectory();
        File tempFile = File('${dir.path}/temp_sos_playback.m4a');
        await tempFile.writeAsBytes(audioBytes);

        await _audioPlayer.play(DeviceFileSource(tempFile.path));

        if (mounted) {
          setState(() {
            _currentlyPlayingUrl = base64Data;
            _isPlaying = true;
            _isAudioLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Audio Play Error: $e");
        if (mounted) setState(() => _isAudioLoading = false);
      }
    }
  }

  // Map Open Function for SOS links
  Future<void> _openMap(String text) async {
    RegExp regExp = RegExp(r"(https?://[^\s]+)");
    var match = regExp.firstMatch(text);

    if (match != null) {
      String url = match.group(0)!;
      Uri mapUri = Uri.parse(url);
      try {
        if (await canLaunchUrl(mapUri)) {
          await launchUrl(mapUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint("Map Open Error: $e");
      }
    }
  }

  // Clickable Links for normal text messages
  Widget _buildLinkableText(String text, bool isMe) {
    final urlRegExp = RegExp(r"((https?:|www\.)[^\s]+)", caseSensitive: false);
    final matches = urlRegExp.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.3,
        ),
      );
    }

    List<InlineSpan> spans = [];
    text.splitMapJoin(
      urlRegExp,
      onMatch: (Match match) {
        final urlMatch = match.group(0)!;
        spans.add(
          TextSpan(
            text: urlMatch,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.blue.shade700,
              fontSize: 15,
              height: 1.3,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.parse(urlMatch.startsWith('http')
                    ? urlMatch
                    : 'https://$urlMatch');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(
          TextSpan(
            text: nonMatch,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        );
        return '';
      },
    );

    return RichText(text: TextSpan(children: spans));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 FIX: Keyboard එක open ද කියලා check කරනවා
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Premium Light Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "Secure Family Chat",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_rounded, size: 12, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  "End-to-End Encrypted",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // CHAT MESSAGES AREA
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('families')
                    .doc(widget.familyCode)
                    .collection('chat')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.deepOrange));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 15),
                          Text("No messages yet.",
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Text("Say hello to your family.",
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  var msgs = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 20),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      var msg = msgs[index].data() as Map<String, dynamic>;
                      bool isMe = msg['senderId'] == _myUid;
                      String type = msg['type'] ?? 'text';

                      return _buildMessageBubble(msg, isMe, type);
                    },
                  );
                },
              ),
            ),

            // 🔥 FIX: MESSAGE INPUT FIELD AREA WITH SMART PADDING
            Container(
              padding: EdgeInsets.only(
                left: 15,
                right: 15,
                top: 15,
                // Keyboard එක open නම් සාමාන්‍ය විදියට 15ක් දෙනවා, නැත්නම් Nav Bar එකෙන් බේරන්න 110ක් දෙනවා
                bottom: isKeyboardOpen ? 15 : 110,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _msgController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Type a secure message...",
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 14),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // CUSTOM MESSAGE BUBBLE WIDGET
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, String type) {
    String timeString = "";
    if (msg['timestamp'] != null) {
      DateTime time = (msg['timestamp'] as Timestamp).toDate();
      timeString = DateFormat('hh:mm a').format(time);
    } else {
      timeString = "Just now";
    }

    // 🔥 PRO FIX: System Alerts UI (For Safe Zones, Battery etc.)
    if (type == 'system_alert') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg['text'] ?? "",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    bool isSOS = type.contains('sos') ||
        (msg['text'] != null && msg['text'].toString().contains('SOS'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 4),
              child: Text(
                msg['senderName'] ?? "Unknown",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSOS ? Colors.red.shade700 : Colors.grey.shade600),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSOS
                        ? Colors.red.shade50
                        : (isMe ? Colors.deepOrange : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 5),
                      bottomRight: Radius.circular(isMe ? 5 : 20),
                    ),
                    border: isSOS
                        ? Border.all(color: Colors.red.shade200, width: 1.5)
                        : null,
                    boxShadow: [
                      if (!isMe || isSOS)
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe && !isSOS
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // SOS LOCATION UI
                      if (type == 'sos_location') ...[
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 5),
                            Text("EMERGENCY LOCATION",
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(msg['text'] ?? "",
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 14)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openMap(msg['text'] ?? ""),
                            icon: const Icon(Icons.map_rounded,
                                color: Colors.white, size: 18),
                            label: const Text("Open Map",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0),
                          ),
                        ),
                      ]

                      // SOS AUDIO UI
                      else if (type == 'sos_audio') ...[
                        Row(
                          children: [
                            Icon(Icons.mic_rounded,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 5),
                            Text("SURROUNDING AUDIO",
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.red.shade100)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.red.shade600,
                                child: _isAudioLoading &&
                                        _currentlyPlayingUrl ==
                                            msg['audioBase64']
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _currentlyPlayingUrl ==
                                                      msg['audioBase64'] &&
                                                  _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        onPressed: () => _playAudio(
                                            msg['audioBase64'] ?? ""),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              const Text("10 Sec Recorded",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87)),
                            ],
                          ),
                        ),
                      ]

                      // NORMAL TEXT UI
                      else ...[
                        _buildLinkableText(msg['text'] ?? "", isMe),
                      ],

                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeString,
                          style: TextStyle(
                            color: isSOS
                                ? Colors.red.shade400
                                : (isMe
                                    ? Colors.white70
                                    : Colors.grey.shade500),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
