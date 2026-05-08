import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ScheduledSmsScreen extends StatelessWidget {
  const ScheduledSmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Scheduled SMS'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Text(
              'Scheduled SMS drafts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Draft scheduling is available. Real sending is handled from the Send SMS screen.',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
