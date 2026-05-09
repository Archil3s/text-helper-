import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdsNoAdsPolicyScreen extends StatefulWidget {
  const AdsNoAdsPolicyScreen({super.key});

  @override
  State<AdsNoAdsPolicyScreen> createState() => _AdsNoAdsPolicyScreenState();
}

class _AdsNoAdsPolicyScreenState extends State<AdsNoAdsPolicyScreen> {
  static const String _reviewedKey = 'text_helper_ads_policy_reviewed';

  bool _loading = true;
  bool _reviewed = false;
  String _status = 'Text Helper is currently documented as ad-free.';

  @override
  void initState() {
    super.initState();
    _loadReviewed();
  }

  Future<void> _loadReviewed() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = prefs.getBool(_reviewedKey) ?? false;
      _loading = false;
      _status = _reviewed
          ? 'Ads/no-ads policy reviewed.'
          : 'Review and confirm the ads/no-ads product policy.';
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
      _status = 'Ads/no-ads policy reviewed.';
    });
  }

  Future<void> _copyPolicy() async {
    await Clipboard.setData(
      const ClipboardData(
        text: '''
Text Helper ads/no-ads policy

Current product state:
- Text Helper is currently ad-free.
- No full-screen ads are shown.
- No video ads are shown.
- No ads are shown during critical scheduling, queueing, sending, backup, restore, or confirmation flows.

If ads are ever added later:
- Never show full-screen blocking ads during critical scheduling flows.
- Never show ads over send confirmation, queue confirmation, backup, restore, or failure-warning screens.
- Avoid loud/video ads in appointment, reminder, and business-message workflows.
- Keep send controls, emergency edits, and restore controls accessible without ad interruption.
- Clearly state the ad policy before release.
''',
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Ads/no-ads policy copied to clipboard.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Ads / No-Ads Policy'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AdsHero(reviewed: _reviewed),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _PolicySection(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  title: 'Current app policy',
                  color: Color(0xFF16A34A),
                  items: [
                    'Text Helper is currently ad-free.',
                    'No full-screen ads are shown.',
                    'No video ads are shown.',
                    'No ads appear during scheduling, queueing, sending, backup, restore, or confirmation flows.',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.exclamationmark_triangle_fill,
                  title: 'If ads are ever added later',
                  color: Color(0xFFF97316),
                  items: [
                    'Never show full-screen blocking ads during critical scheduling flows.',
                    'Never show ads over send confirmation or queue confirmation screens.',
                    'Never interrupt backup, restore, failure-warning, or emergency edit screens.',
                    'Avoid loud/video ads in appointment and reminder workflows.',
                  ],
                ),
                const _PolicySection(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Trust rules',
                  color: Color(0xFF2563EB),
                  items: [
                    'Keep send controls and restore controls accessible without ad interruption.',
                    'State the ad policy clearly before release.',
                    'Do not imply paid/no-ads features unless billing is intentionally added.',
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
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AdsHero extends StatelessWidget {
  const _AdsHero({required this.reviewed});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final color = reviewed ? const Color(0xFF16A34A) : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, const Color(0xFF111827)],
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
          const Icon(CupertinoIcons.hand_raised_fill, color: Colors.white, size: 36),
          const SizedBox(height: 16),
          const Text(
            'Ad-free policy',
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
            'No ads should interrupt scheduling, sending, backup, restore, or confirmation.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _HeroPill(label: 'Current', value: 'AD-FREE'),
              SizedBox(width: 10),
              _HeroPill(label: 'Blocking ads', value: 'NO'),
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
                fontSize: 15,
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
                  Icon(CupertinoIcons.circle_fill, size: 7, color: color),
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
          const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF0A84FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(height: 1.3, fontWeight: FontWeight.w800),
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