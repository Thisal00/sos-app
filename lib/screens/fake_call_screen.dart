import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String callerRole;

  const FakeCallScreen({
    super.key,
    this.callerName = "Mom",
    this.callerRole = "Mobile",
  });

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  Timer? _vibrationTimer;
  bool _isCallAnswered = false;
  int _callDuration = 0;
  Timer? _callTimer;

  // Buttons state for realism
  bool _isMuted = false;
  bool _isSpeaker = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  void _startRinging() {
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.heavyImpact();
    });
  }

  void _answerCall() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isCallAnswered = true;
    });
    _vibrationTimer?.cancel();

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _endCall() {
    HapticFeedback.lightImpact();
    _vibrationTimer?.cancel();
    _callTimer?.cancel();
    Navigator.pop(context);
  }

  String get _formattedTime {
    int minutes = _callDuration ~/ 60;
    int seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //  Deep Dark Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E272E), Color(0xFF000000)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                //  Caller Information
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isCallAnswered ? _formattedTime : widget.callerRole,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 40),

                //  Profile Avatar
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 90,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                //  THE MAGIC: Real Call UI appear after answering
                if (_isCallAnswered) _buildActiveCallOptions(),

                const Spacer(),

                //  Call Control Buttons
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 60, left: 40, right: 40),
                  child: !_isCallAnswered
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCallButton(
                              label: "Decline",
                              icon: Icons.call_end,
                              color: Colors.redAccent,
                              onTap: _endCall,
                            ),
                            _buildCallButton(
                              label: "Accept",
                              icon: Icons.call,
                              color: Colors.greenAccent.shade700,
                              onTap: _answerCall,
                            ),
                          ],
                        )
                      : Center(
                          child: _buildCallButton(
                              label: "End Call",
                              icon: Icons.call_end,
                              color: Colors.redAccent,
                              onTap: _endCall,
                              size: 75,
                              iconSize: 35),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎛️ The options grid when call is answered (Mute, Speaker etc)
  Widget _buildActiveCallOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOptionIcon(Icons.mic_off, "mute", _isMuted, () {
                setState(() => _isMuted = !_isMuted);
              }),
              _buildOptionIcon(Icons.dialpad, "keypad", false, () {}),
              _buildOptionIcon(Icons.volume_up, "speaker", _isSpeaker, () {
                setState(() => _isSpeaker = !_isSpeaker);
              }),
            ],
          ),
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOptionIcon(Icons.add, "add call", false, () {}),
              _buildOptionIcon(Icons.videocam, "FaceTime", false, () {}),
              _buildOptionIcon(Icons.person, "contacts", false, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionIcon(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isActive ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 75,
    double iconSize = 35,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
