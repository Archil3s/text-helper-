import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background_alarm_service.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  static const String _reviewedKey = 'text_helper_battery_warning_reviewed';

  final BackgroundAlarmService _alarmService = BackgroundAlarmService();

  bool _loading = true;
  bool _busy = false;
  bool _isUnrestricted = false;
  bool _reviewed = false;

  String _status =
      'Battery optimization can delay or stop background scheduled texts.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final reviewed = prefs.getBool(_reviewedKey) ?? false;
    final unrestricted = await _alarmService.isIgnoringBatteryOptimizations();

    if (!mounted) {
      return;
    }

    setState(() {
      _reviewed = reviewed;
      _isUnrestricted = unrestricted;
      _loading = false;
      _status = unrestricted
          ? 'Battery optimization is unrestricted for this app.'
          : 'Battery optimization may restrict background sends.';
    });
  }

  Future<void> _openSettings() async {
    setState(() {
      _busy = true;
      _status =
          'Opening Android battery settings. Set Text Helper to unrestricted if available.';
    });

    await _alarmService.openBatteryOptimizationSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _status = 'Return here and tap Refresh after changing battery settings.';
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
      _status = 'Battery warning reviewed.';
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _status = 'Checking battery optimization status...';
    });

    final unrestricted = await _alarmService.isIgnoringBatteryOptimizations();

    if (!mounted) {
      return;
    }

    setState(() {
      _isUnrestricted = unrestricted;
      _busy = false;
      _status = unrestricted
          ? 'Battery optimization is unrestricted for this app.'
          : 'Battery optimization may still restrict background sends.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _reviewed && _isUnrestricted;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Battery Optimization'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _BatteryHero(
                  ready: ready,
                  unrestricted: _isUnrestricted,
                  reviewed: _reviewed,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _CheckCard(
                  title: 'Battery unrestricted',
                  subtitle: _isUnrestricted
                      ? 'Android reports Text Helper is ignoring battery optimization.'
                      : 'Android may delay or stop closed-app alarms while battery optimization is active.',
                  passed: _isUnrestricted,
                ),
                _CheckCard(
                  title: 'Warning reviewed',
                  subtitle: _reviewed
                      ? 'You have reviewed the background battery warning.'
                      : 'Review this warning before depending on closed-app sends.',
                  passed: _reviewed,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _openSettings,
                  icon: const Icon(CupertinoIcons.battery_25),
                  label: const Text('Open battery optimization settings'),
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
                  onPressed: _busy ? null : _markReviewed,
                  icon: const Icon(CupertinoIcons.check_mark_circled),
                  label: const Text('I reviewed this warning'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Guidance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'For reliable closed-app sending, set Text Helper to Unrestricted or Not optimized in Android battery settings. The exact wording depends on the phone brand.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _SurfaceCard(
                  child: Text(
                    'Do not force-stop the app from Android settings. Android will usually block alarms after a force-stop until the app is opened again.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _SurfaceCard(
                  child: Text(
                    'Some phones have extra battery managers. If background texts are late or missed, also check brand-specific settings such as Sleeping Apps, App Launch, Auto-start, Adaptive Battery, or Background Usage Limits.',
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

class _BatteryHero extends StatelessWidget {
  const _BatteryHero({
    required this.ready,
    required this.unrestricted,
    required this.reviewed,
  });

  final bool ready;
  final bool unrestricted;
  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF16A34A) : const Color(0xFFF97316);

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
            CupertinoIcons.battery_25,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Battery optimization',
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
            ready
                ? 'Battery setup looks ready for background sending.'
                : 'Review battery settings before relying on background sends.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(
                value: unrestricted ? 'OK' : 'WARN',
                label: 'battery',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: reviewed ? 'YES' : 'NO',
                label: 'reviewed',
              ),
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

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.subtitle,
    required this.passed,
  });

  final String title;
  final String subtitle;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
      borderColor: passed ? null : color,
      child: Row(
        children: [
          Icon(
            passed
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_triangle_fill,
            color: color,
          ),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
