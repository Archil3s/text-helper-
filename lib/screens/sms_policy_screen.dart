import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmsPolicyScreen extends StatefulWidget {
  const SmsPolicyScreen({super.key});

  @override
  State<SmsPolicyScreen> createState() => _SmsPolicyScreenState();
}

class _SmsPolicyScreenState extends State<SmsPolicyScreen> {
  static const String _reviewedKey = 'text_helper_sms_only_policy_reviewed';

  bool _loading = true;
  bool _reviewed = false;

  String _status =
      'Text Helper currently sends SMS text messages only. MMS/media is not supported.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final reviewed = prefs.getBool(_reviewedKey) ?? false;

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = reviewed;
      _loading = false;
      _status = reviewed
          ? 'SMS-only policy reviewed.'
          : 'Review this before using Text Helper with clients or appointment reminders.';
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
      _status = 'SMS-only policy reviewed.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SMS-only policy marked as reviewed.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewedKey, false);

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = false;
      _status = 'SMS-only policy review reset.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('SMS / MMS Policy'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _resetReviewed,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
          ),
        ],
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
                  icon: CupertinoIcons.check_mark_circled_solid,
                  title: 'What Text Helper supports',
                  body:
                      'Text Helper sends plain SMS text reminders through Android SMS. It is designed for appointment reminders, follow-ups, confirmations, test sends, and scheduled text-only messages.',
                  color: Color(0xFF16A34A),
                ),
                const _PolicySection(
                  icon: CupertinoIcons.xmark_circle_fill,
                  title: 'What Text Helper does not support yet',
                  body:
                      'Text Helper does not currently send MMS. That means no images, videos, audio files, PDFs, contact cards, GIFs, stickers, or other media attachments.',
                  color: Color(0xFFEF4444),
                ),
                const _PolicySection(
                  icon: CupertinoIcons.info_circle_fill,
                  title: 'Delivery wording',
                  body:
                      'The app uses “Sent to Android SMS service” unless a real carrier/device delivery callback is received. It should not claim “Delivered” unless Android provides a delivery receipt.',
                  color: Color(0xFF0A84FF),
                ),
                const _PolicySection(
                  icon: CupertinoIcons.exclamationmark_triangle_fill,
                  title: 'Carrier limits still apply',
                  body:
                      'Carriers may split long SMS messages, charge per segment, block high-volume sending, delay delivery, or fail delivery. Text Helper cannot guarantee final carrier delivery.',
                  color: Color(0xFFF97316),
                ),
                const _PolicySection(
                  icon: CupertinoIcons.lock_shield_fill,
                  title: 'Safe wording for users',
                  body:
                      'Tell users this is a scheduled SMS text reminder app. Do not advertise it as an MMS, media campaign, image messaging, or file messaging app unless those features are intentionally added later.',
                  color: Color(0xFF111827),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _markReviewed,
                  icon: Icon(
                    _reviewed
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark,
                  ),
                  label: Text(
                    _reviewed
                        ? 'Policy reviewed'
                        : 'I understand this is SMS text only',
                  ),
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
                const _SurfaceCard(
                  child: Text(
                    'Future MMS support should be built as a separate feature with explicit media picker UI, carrier/device checks, clear limitations, and separate testing. Until then, keep all product wording SMS-only.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
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
    final color = reviewed ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8);

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
            CupertinoIcons.chat_bubble_text_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'SMS text only',
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
                ? 'Policy reviewed. The app should be described as SMS text-only.'
                : 'Clarifies that images, videos, files, and MMS are not supported yet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: 'SMS', label: 'supported'),
              const SizedBox(width: 10),
              _HeroMetric(value: 'NO', label: 'MMS/media'),
              const SizedBox(width: 10),
              _HeroMetric(value: reviewed ? 'YES' : 'NO', label: 'reviewed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

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
                fontSize: 18,
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
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
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
  const _SurfaceCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
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
