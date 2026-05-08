import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsPrivacyScreen extends StatefulWidget {
  const PermissionsPrivacyScreen({super.key});

  @override
  State<PermissionsPrivacyScreen> createState() =>
      _PermissionsPrivacyScreenState();
}

class _PermissionsPrivacyScreenState extends State<PermissionsPrivacyScreen> {
  static const String _reviewedKey = 'text_helper_permissions_privacy_reviewed';

  bool _loading = true;
  bool _reviewed = false;

  String _status =
      'Review why Text Helper needs SMS and background permissions.';

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
          ? 'Permissions and privacy explanation reviewed.'
          : 'Review this before using background SMS scheduling.';
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
      _status = 'Permissions and privacy explanation reviewed.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permissions and privacy marked as reviewed.'),
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
      _status = 'Permissions and privacy review reset.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Permissions & Privacy'),
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
                _PrivacyHero(reviewed: _reviewed),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _PermissionSection(
                  icon: Icons.sms_outlined,
                  title: 'Why SMS permission is needed',
                  body:
                      'Text Helper needs Android SMS permission to send scheduled SMS text reminders from your phone number. Without this permission, the app can queue reminders but cannot hand them to Android SMS.',
                  color: Color(0xFF0A84FF),
                ),
                const _PermissionSection(
                  icon: Icons.alarm_on_outlined,
                  title: 'Why exact alarm permission is needed',
                  body:
                      'Android can delay normal background work. Exact alarms help scheduled reminders trigger closer to the selected time, especially when the app is closed.',
                  color: Color(0xFF6366F1),
                ),
                const _PermissionSection(
                  icon: Icons.battery_alert_outlined,
                  title: 'Why battery settings matter',
                  body:
                      'Some phones stop apps in the background to save battery. If Text Helper is restricted, scheduled texts may be late, blocked, or left pending until the app is opened again.',
                  color: Color(0xFFF97316),
                ),
                const _PermissionSection(
                  icon: Icons.storage_outlined,
                  title: 'What data stays local',
                  body:
                      'Contacts, reminders, templates, groups, send logs, delivery receipt events, and backup data are stored locally on the device using app storage. CSV and JSON exports are copied only when you choose to export them.',
                  color: Color(0xFF16A34A),
                ),
                const _PermissionSection(
                  icon: Icons.contacts_outlined,
                  title: 'Where contact names are stored',
                  body:
                      'Contact names live only in the contacts model/store. Reminder and log base models should rely on contact IDs, phone numbers, message text, timestamps, and statuses instead of duplicating names.',
                  color: Color(0xFF111827),
                ),
                const _PermissionSection(
                  icon: Icons.security_outlined,
                  title: 'Why antivirus apps may warn',
                  body:
                      'Some antivirus apps warn about any app that can send SMS or run background alarms. Those warnings are based on capability. Text Helper uses those capabilities for scheduled SMS automation and shows in-app explanations so users understand why.',
                  color: Color(0xFFEF4444),
                ),
                const _PermissionSection(
                  icon: Icons.lock_outline,
                  title: 'What Text Helper should not do',
                  body:
                      'Text Helper should not hide permissions, claim carrier delivery unless a real delivery callback exists, store unnecessary contact-name copies in logs, or imply MMS/RCS/WhatsApp support unless those features are intentionally implemented.',
                  color: Color(0xFF6B7280),
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
                        ? 'Privacy explanation reviewed'
                        : 'I understand these permissions',
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
                    'For best trust, keep permission prompts close to the feature that needs them. Do not request broad permissions before the user understands why they are needed.',
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

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero({required this.reviewed});

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
            Icons.privacy_tip_outlined,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Permissions & privacy',
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
                ? 'Reviewed. Permission wording is clear for users.'
                : 'Explains SMS, background alarms, battery settings, local data, and antivirus warnings.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: 'SMS', label: 'permission'),
              const SizedBox(width: 10),
              _HeroMetric(value: 'LOCAL', label: 'data'),
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

class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
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
