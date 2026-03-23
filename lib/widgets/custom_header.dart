import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget {
  const CustomHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Profile Image
            const CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
            const SizedBox(width: 15),
            // Greeting
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GOOD MORNING",
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600], letterSpacing: 1),
                ),
                const Text(
                  "Suba Dawasak,\nNimal!",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
                ),
              ],
            ),
          ],
        ),
        // Notification Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: const Icon(Icons.notifications_none),
        )
      ],
    );
  }
}
