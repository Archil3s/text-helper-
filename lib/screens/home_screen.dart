import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'channel_test_lab_screen.dart';
import 'contacts_screen.dart';
import 'direct_sms_screen.dart';
import 'send_history_screen.dart';
import 'send_queue_screen.dart';
import 'schedule_center_screen.dart';
import 'whatsapp_handoff_screen.dart';
import 'whatsapp_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_HomeItem>[
      const _HomeItem(
        icon: CupertinoIcons.lab_flask_solid,
        title: 'Channel Test Lab',
        subtitle: 'SMS, RCS, WhatsApp, and force-stop tests.',
        screen: ChannelTestLabScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.chat_bubble_2_fill,
        title: 'WhatsApp Setup',
        subtitle: 'WhatsApp overview.',
        screen: WhatsAppSetupScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.arrow_up_right_square_fill,
        title: 'WhatsApp Handoff',
        subtitle: 'Open WhatsApp with a prepared draft.',
        screen: WhatsAppHandoffScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.paperplane_fill,
        title: 'Direct SMS',
        subtitle: 'Send a real SMS now.',
        screen: DirectSmsScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.calendar_badge_clock,
        title: 'Schedule Center',
        subtitle: 'Create, review, and track due SMS reminders.',
        screen: ScheduleCenterScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.tray_full_fill,
        title: 'Send Queue',
        subtitle: 'Review pending, failed, and retryable sends.',
        screen: SendQueueScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.doc_text_search,
        title: 'Send History',
        subtitle: 'View sent, failed, blocked, and retryable sends.',
        screen: SendHistoryScreen(),
      ),
      const _HomeItem(
        icon: CupertinoIcons.person_2_fill,
        title: 'Contacts',
        subtitle: 'Manage saved contacts.',
        screen: ContactsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('All Features'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          ...items.map(
            (item) => _HomeButton(
              item: item,
              onTap: () => _open(context, item.screen),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeItem {
  const _HomeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.list_bullet,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'All Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Core screens for testing Text Helper.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.item,
    required this.onTap,
  });

  final _HomeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(item.icon, color: const Color(0xFF0A84FF), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
