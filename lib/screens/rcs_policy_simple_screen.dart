import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RcsPolicySimpleScreen extends StatelessWidget {
  const RcsPolicySimpleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('RCS / SMS Policy'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _HeroCard(),
          SizedBox(height: 16),
          _PolicyCard(
            icon: CupertinoIcons.check_mark_circled_solid,
            title: 'SMS is the automatic channel',
            text:
                'Text Helper can send SMS automatically because Android exposes SMS sending APIs with permission.',
            color: Color(0xFF16A34A),
          ),
          _PolicyCard(
            icon: CupertinoIcons.info_circle_fill,
            title: 'RCS is not the automatic channel',
            text:
                'RCS is controlled by the phone messaging app and carrier support. Text Helper treats RCS as policy, wording, and fallback guidance.',
            color: Color(0xFFF97316),
          ),
          _PolicyCard(
            icon: CupertinoIcons.arrow_down_right_circle_fill,
            title: 'Fallback rule',
            text:
                'For automation, use SMS. If a customer prefers RCS, open the default messaging app manually or use SMS fallback.',
            color: Color(0xFF0A84FF),
          ),
          _PolicyCard(
            icon: CupertinoIcons.shield_fill,
            title: 'Consent and safety',
            text:
                'Bulk sending and auto replies should only target approved contacts, with Do Not Send and cooldown protections.',
            color: Color(0xFF111827),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_text_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'RCS / SMS Policy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'SMS handles automation. RCS is treated as a compatibility and fallback layer.',
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

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
