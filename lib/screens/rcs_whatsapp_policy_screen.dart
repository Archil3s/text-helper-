import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RcsWhatsAppPolicyScreen extends StatefulWidget {
  const RcsWhatsAppPolicyScreen({super.key});

  @override
  State<RcsWhatsAppPolicyScreen> createState() =>
      _RcsWhatsAppPolicyScreenState();
}

class _RcsWhatsAppPolicyScreenState extends State<RcsWhatsAppPolicyScreen> {
  static const String _reviewedKey = 'text_helper_rcs_whatsapp_policy_reviewed';

  bool _loading = true;
  bool _reviewed = false;
  String _status =
      'Review SMS, RCS, WhatsApp, and media limits before relying on automation.';

  @override
  void initState() {
    super.initState();
    _loadReviewedState();
  }

  Future<void> _loadReviewedState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = prefs.getBool(_reviewedKey) ?? false;
      _loading = false;
      _status = _reviewed
          ? 'Policy reviewed. Text Helper is SMS-only automation.'
          : 'Policy not reviewed yet.';
    });
  }

  Future<void> _markReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewedKey, true);

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = true;
      _status = 'Policy reviewed.';
    });
  }

  Future<void> _copyPolicy() async {
    await Clipboard.setData(
      const ClipboardData(
        text: '''
Text Helper messaging policy

Text Helper currently sends SMS text messages only.

Supported:
- Scheduled SMS text reminders
- Appointment follow-up text messages
- Confirmation text messages
- Test SMS messages to approved test contacts
- Background SMS scheduling through Android SMS APIs where device permissions allow it

Not supported:
- RCS messaging
- WhatsApp messaging
- WhatsApp Business automation
- MMS media messages
- Images, videos, audio, PDFs, stickers, contact cards, or files
- Auto-replies in RCS, WhatsApp, Messenger, Telegram, Signal, or other chat apps

Important:
- RCS behavior is controlled by the default Messages app, carrier, Google/Android settings, and recipient support.
- Text Helper does not control whether an SMS upgrades to RCS in another app.
- WhatsApp automation is not part of this SMS scheduler.
- Text Helper should describe delivery carefully: "Sent to Android SMS service" unless a real carrier/device delivery callback is available.
''',
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Policy copied to clipboard.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('RCS & WhatsApp Policy'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PolicyHero(reviewed: _reviewed),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _PolicySection(
                  icon: CupertinoIcons.chat_bubble_text_fill,
                  title: 'Supported',
                  color: Color(0xFF16A34A),
                  items: [
                    'Scheduled SMS text reminders',
                    'Appointment follow-up text messages',
                    'Confirmation text messages',
                    'Test SMS messages to approved test contacts',
                    'Background SMS scheduling where Android permissions allow it',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.xmark_circle_fill,
                  title: 'Not supported',
                  color: Color(0xFFDC2626),
                  items: [
                    'RCS messaging',
                    'WhatsApp or WhatsApp Business automation',
                    'MMS media messages',
                    'Images, videos, audio, PDFs, stickers, contact cards, or files',
                    'Auto-replies in other chat apps',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.info_circle_fill,
                  title: 'RCS expectation',
                  color: Color(0xFF2563EB),
                  items: [
                    'RCS is controlled by the default Messages app, carrier, Android settings, and recipient support.',
                    'Text Helper does not control whether another app upgrades a message to RCS.',
                    'For reliable automation from this app, treat Text Helper as SMS-only.',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.exclamationmark_triangle_fill,
                  title: 'WhatsApp expectation',
                  color: Color(0xFFF97316),
                  items: [
                    'WhatsApp automation is not part of this SMS scheduler.',
                    'Text Helper does not send WhatsApp reminders.',
                    'Text Helper does not read, reply to, or schedule WhatsApp messages.',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  title: 'Delivery wording',
                  color: Color(0xFF7C3AED),
                  items: [
                    'Use "Sent to Android SMS service" unless Android provides a real delivery callback.',
                    'Do not claim WhatsApp, RCS, or cross-app delivery.',
                    'Do not imply media or chat-app automation exists unless intentionally implemented later.',
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _markReviewed,
                  icon: Icon(
                    _reviewed
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark_circled,
                  ),
                  label: Text(_reviewed ? 'Reviewed' : 'Mark policy reviewed'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _copyPolicy,
                  icon: const Icon(CupertinoIcons.doc_on_clipboard),
                  label: const Text('Copy policy text'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PolicyHero extends StatelessWidget {
  const _PolicyHero({required this.reviewed});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final color = reviewed ? const Color(0xFF16A34A) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.chat_bubble_2_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'SMS-only automation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reviewed
                ? 'RCS and WhatsApp expectations are reviewed.'
                : 'Clarify SMS, RCS, WhatsApp, and media limits before release.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              _HeroPill(label: 'SMS', value: 'YES'),
              SizedBox(width: 10),
              _HeroPill(label: 'RCS', value: 'NO'),
              SizedBox(width: 10),
              _HeroPill(label: 'WhatsApp', value: 'NO'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.circle_fill,
                    size: 7,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
