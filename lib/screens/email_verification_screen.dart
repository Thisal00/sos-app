import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sos/screens/main_screen.dart';
import 'package:sos/screens/auth/login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    // veryfy
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      sendVerificationEmail();
      // all 3 secodes check  verfy
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel(); // Screen Timer end
    super.dispose();
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();

      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 15));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending email: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> checkEmailVerified() async {
    try {
      // Firebase get   data
      await FirebaseAuth.instance.currentUser?.reload();

      setState(() {
        isEmailVerified =
            FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      });

      if (isEmailVerified) {
        timer?.cancel(); //  Timer

        // Green Mark Main Screen
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error reloading user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Security Check",
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: isEmailVerified
                ? _buildSuccessState()
                : _buildVerificationState(),
          ),
        ),
      ),
    );
  }

  // (Spam Warning
  Widget _buildVerificationState() {
    return Padding(
      key: const ValueKey("waiting"),
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_rounded,
                size: 80, color: Colors.orange),
          ),
          const SizedBox(height: 30),
          const Text(
            "Verify Your Email",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Text(
            "We've sent a verification link to:\n${FirebaseAuth.instance.currentUser?.email}",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 30),

          // Spam Folder Warning Box
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.blue, size: 24),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "Don't see the email? Please check your Spam or Junk folder.",
                    style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          const CircularProgressIndicator(color: Colors.deepOrange),
          const SizedBox(height: 15),
          const Text("Waiting for verification...",
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canResendEmail ? sendVerificationEmail : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                canResendEmail ? "Resend Email" : "Wait a moment to resend...",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: () async {
              timer?.cancel();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            child: const Text("Cancel & Logout",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // verfy and  green  tick  come
  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey("success"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 100, color: Colors.green),
        ),
        const SizedBox(height: 30),
        const Text(
          "Email Verified!",
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green),
        ),
        const SizedBox(height: 15),
        const Text(
          "Redirecting to dashboard...",
          style: TextStyle(
              fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
