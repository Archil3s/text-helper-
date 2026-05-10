import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'whatsapp_handoff_screen.dart';
import 'whatsapp_recurring_handoff_screen.dart';

class WhatsAppSetupScreen extends StatelessWidget {
  const WhatsAppSetupScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('WhatsApp Setup'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          const _CurrentModeCard(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _open(context, const WhatsAppHandoffScreen()),
            icon: const Icon(CupertinoIcons.arrow_up_right_square_fill),
            label: const Text('Open One-Time WhatsApp Draft'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                _open(context, const WhatsAppRecurringHandoffScreen()),
            icon: const Icon(CupertinoIcons.repeat),
            label: const Text('Open Recurring WhatsApp'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          const _FinishedCard(),
          const SizedBox(height: 16),
          const _BusinessApiCard(),
          const SizedBox(height: 16),
          const _SafetyCard(),
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
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'WhatsApp Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'WhatsApp is supported as manual handoff: one-time or recurring drafts. The user presses Send in WhatsApp.',
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

class _CurrentModeCard extends StatelessWidget {
  const _CurrentModeCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Current WhatsApp mode'),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manual handoff',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Text Helper prepares WhatsApp drafts and opens WhatsApp. It does not press Send.',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Available now'),
          SizedBox(height: 12),
          _ChecklistRow(done: true, text: 'One-time WhatsApp draft handoff.'),
          _ChecklistRow(done: true, text: 'Recurring WhatsApp draft handoff.'),
          _ChecklistRow(done: true, text: 'Approved contact picker.'),
          _ChecklistRow(done: true, text: 'Template preview buttons.'),
          _ChecklistRow(done: true, text: 'Send History and Timeline logging.'),
        ],
      ),
    );
  }
}

class _BusinessApiCard extends StatelessWidget {
  const _BusinessApiCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Later: official Business API'),
          SizedBox(height: 12),
          _ChecklistRow(done: false, text: 'Backend sends approved templates.'),
          _ChecklistRow(
              done: false, text: 'WhatsApp Business Account approval.'),
          _ChecklistRow(done: false, text: 'Webhook for delivery statuses.'),
          _ChecklistRow(
              done: false,
              text: 'WhatsApp-specific opt-in and Do Not Send rules.'),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_shield_fill,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'This app does not use screen tapping, accessibility tricks, clipboard automation, WhatsApp Web scraping, or unofficial WhatsApp clients.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.text,
  });

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            color: done ? Color(0xFF16A34A) : CupertinoColors.systemGrey,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: CupertinoColors.label,
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}
