import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CoreFeatureRegressionScreen extends StatefulWidget {
  const CoreFeatureRegressionScreen({super.key});

  @override
  State<CoreFeatureRegressionScreen> createState() =>
      _CoreFeatureRegressionScreenState();
}

class _CoreFeatureRegressionScreenState
    extends State<CoreFeatureRegressionScreen> {
  final List<_RegressionCheck> _checks = <_RegressionCheck>[
    const _RegressionCheck(
      title: 'SMS scheduling remains visible',
      category: 'SMS',
      priority: 'Critical',
      description:
          'Home must expose Automation, Schedule Builder, Visual Calendar, and Background Scheduler entry points.',
      evidence:
          'Open Home and confirm SMS scheduling entry points are visible.',
    ),
    const _RegressionCheck(
      title: 'SMS reminder creation still works',
      category: 'SMS',
      priority: 'Critical',
      description:
          'Users must be able to create a reminder after each update without finding a moved or hidden flow.',
      evidence:
          'Open Automation or Visual Calendar and confirm reminder creation is reachable.',
    ),
    const _RegressionCheck(
      title: 'Background sending remains reachable',
      category: 'Background',
      priority: 'Critical',
      description:
          'Background Scheduler, Background Wizard, battery guidance, and permission checks must not disappear.',
      evidence:
          'Open Background Scheduler, Background Wizard, and Battery Optimization.',
    ),
    const _RegressionCheck(
      title: 'Send history remains visible',
      category: 'History',
      priority: 'Critical',
      description:
          'Users must be able to inspect sent, failed, blocked, skipped, and retryable sends after each update.',
      evidence: 'Open Send History and Message Timeline.',
    ),
    const _RegressionCheck(
      title: 'Duplicate-send protection remains visible',
      category: 'Safety',
      priority: 'Critical',
      description:
          'The app must keep recipient audit, bulk-send safety, and duplicate-send guardrails visible.',
      evidence: 'Open Recipient Audit and Bulk Send Safety.',
    ),
    const _RegressionCheck(
      title: 'Do Not Send controls remain visible',
      category: 'Safety',
      priority: 'Critical',
      description:
          'Do Not Send controls must remain reachable so blocked recipients cannot accidentally receive texts.',
      evidence:
          'Open Contact Groups and confirm Do Not Send controls are present.',
    ),
    const _RegressionCheck(
      title: 'Backup and restore remains visible',
      category: 'Data safety',
      priority: 'Critical',
      description:
          'Backup and restore must remain visible before any update that changes local data models.',
      evidence:
          'Open Backup and Restore and confirm export and restore options are visible.',
    ),
    const _RegressionCheck(
      title: 'CSV import and export remains visible',
      category: 'Data safety',
      priority: 'High',
      description:
          'Bulk contact and reminder import/export tools must not disappear after update.',
      evidence: 'Open CSV Import / Export.',
    ),
    const _RegressionCheck(
      title: 'Template manager remains visible',
      category: 'Messages',
      priority: 'High',
      description:
          'Template creation, copy, edit, and preview flows must remain available after update.',
      evidence: 'Open Template Manager.',
    ),
    const _RegressionCheck(
      title: 'Notification test remains visible',
      category: 'Notifications',
      priority: 'High',
      description:
          'Users need a sound, vibration, and permission test before trusting scheduled reminders.',
      evidence: 'Open Notification Sound Test.',
    ),
    const _RegressionCheck(
      title: 'SMS-only policy remains visible',
      category: 'Policy',
      priority: 'High',
      description:
          'The app must clearly say that it sends SMS text only and does not send MMS, WhatsApp, or RCS.',
      evidence: 'Open SMS / MMS Policy and RCS & WhatsApp Policy.',
    ),
    const _RegressionCheck(
      title: 'WhatsApp automation is not silently enabled',
      category: 'Policy',
      priority: 'High',
      description:
          'WhatsApp automation must not appear as a hidden or half-enabled feature because it is fragile and policy-sensitive.',
      evidence:
          'Confirm WhatsApp is described as unsupported or policy-only, not as an active send path.',
    ),
    const _RegressionCheck(
      title: 'Auto-reply status is explicit',
      category: 'Phone features',
      priority: 'High',
      description:
          'Missed-call auto-reply and after-call auto-reply must not silently disappear or appear broken.',
      evidence:
          'Confirm unsupported phone features are marked as unavailable or roadmap, not hidden.',
    ),
    const _RegressionCheck(
      title: 'Pricing or access does not hide core local SMS tools',
      category: 'Access',
      priority: 'Critical',
      description:
          'Trial, subscription, or entitlement states must not unexpectedly hide local SMS scheduling screens.',
      evidence:
          'Check free or signed-out state and confirm core local SMS tools remain visible.',
    ),
    const _RegressionCheck(
      title: 'Version and build identity are visible',
      category: 'Release QA',
      priority: 'Medium',
      description:
          'Testers must be able to identify the installed build quickly when reporting bugs.',
      evidence:
          'Open Home and confirm build identity or version entry point is visible.',
    ),
    const _RegressionCheck(
      title: 'Regression report can be copied',
      category: 'Release QA',
      priority: 'Medium',
      description:
          'The release tester must be able to copy the regression result into a commit or release note.',
      evidence: 'Tap Copy report from this screen.',
    ),
  ];

  late final List<bool> _passed =
      List<bool>.filled(_checks.length, false, growable: false);

  int get _passedCount {
    return _passed.where((value) => value).length;
  }

  int get _remainingCount {
    return _checks.length - _passedCount;
  }

  double get _progress {
    if (_checks.isEmpty) {
      return 0;
    }

    return _passedCount / _checks.length;
  }

  bool get _allPassed {
    return _passed.every((value) => value);
  }

  String get _decision {
    return _allPassed ? 'PASS' : 'BLOCKED';
  }

  void _toggle(int index, bool value) {
    setState(() {
      _passed[index] = value;
    });
  }

  void _markCriticalPassed() {
    setState(() {
      for (var index = 0; index < _checks.length; index += 1) {
        if (_checks[index].priority == 'Critical') {
          _passed[index] = true;
        }
      }
    });
  }

  void _markAllPassed() {
    setState(() {
      for (var index = 0; index < _passed.length; index += 1) {
        _passed[index] = true;
      }
    });
  }

  void _reset() {
    setState(() {
      for (var index = 0; index < _passed.length; index += 1) {
        _passed[index] = false;
      }
    });
  }

  Future<void> _copyReport() async {
    final buffer = StringBuffer();

    buffer.writeln('Text Helper core feature regression report');
    buffer.writeln('Decision: $_decision');
    buffer.writeln('Passed: $_passedCount of ${_checks.length}');
    buffer.writeln('Remaining: $_remainingCount');
    buffer.writeln('');

    for (var index = 0; index < _checks.length; index += 1) {
      final check = _checks[index];
      final state = _passed[index] ? 'PASS' : 'OPEN';

      buffer.writeln(
          '$state - ${check.priority} - ${check.category} - ${check.title}');
      buffer.writeln('Evidence: ${check.evidence}');
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Regression report copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyReleaseBlockers() async {
    final buffer = StringBuffer();

    buffer.writeln('Open release blockers');
    buffer.writeln('');

    for (var index = 0; index < _checks.length; index += 1) {
      if (_passed[index]) {
        continue;
      }

      final check = _checks[index];
      buffer.writeln('${check.priority} - ${check.category} - ${check.title}');
      buffer.writeln(check.description);
      buffer.writeln('Evidence needed: ${check.evidence}');
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open blockers copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _allPassed ? const Color(0xFF16A34A) : const Color(0xFFF97316);
    final percent = (_progress * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Core Regression Checks'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _copyReport,
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
          ),
          IconButton(
            onPressed: _reset,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroCard(
            passedCount: _passedCount,
            totalCount: _checks.length,
            remainingCount: _remainingCount,
            allPassed: _allPassed,
            percent: percent,
            statusColor: statusColor,
          ),
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Row(
              children: [
                Icon(
                  _allPassed
                      ? CupertinoIcons.checkmark_shield_fill
                      : CupertinoIcons.exclamationmark_triangle_fill,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _allPassed
                        ? 'Core regression gate passed for this build.'
                        : 'Release remains blocked until all checks pass.',
                    style: const TextStyle(
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _markCriticalPassed,
                  icon: const Icon(CupertinoIcons.exclamationmark_shield_fill),
                  label: const Text('Critical pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _markAllPassed,
                  icon: const Icon(CupertinoIcons.check_mark_circled),
                  label: const Text('All pass'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _copyReport,
                  icon: const Icon(CupertinoIcons.doc_text_fill),
                  label: const Text('Copy report'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyReleaseBlockers,
                  icon: const Icon(CupertinoIcons.flag_fill),
                  label: const Text('Copy blockers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Checklist',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _checks.length; index += 1)
            _RegressionCard(
              check: _checks[index],
              passed: _passed[index],
              onChanged: (value) => _toggle(index, value),
            ),
          const SizedBox(height: 12),
          const _SurfaceCard(
            child: Text(
              'Run this screen before every release branch push. If any core SMS scheduling, reminder, backup, safety, access, policy, or navigation entry point disappears, stop release and fix that regression first.',
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

class _RegressionCheck {
  const _RegressionCheck({
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.evidence,
  });

  final String title;
  final String category;
  final String priority;
  final String description;
  final String evidence;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.passedCount,
    required this.totalCount,
    required this.remainingCount,
    required this.allPassed,
    required this.percent,
    required this.statusColor,
  });

  final int passedCount;
  final int totalCount;
  final int remainingCount;
  final bool allPassed;
  final int percent;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor, const Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.checkmark_shield_fill,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(height: 16),
          const Text(
            'Core feature regression',
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
            allPassed
                ? 'Release gate passed.'
                : '$remainingCount item(s) still block release.',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Metric(value: '$passedCount/$totalCount', label: 'passed'),
              const SizedBox(width: 10),
              _Metric(value: '$remainingCount', label: 'open'),
              const SizedBox(width: 10),
              _Metric(value: '$percent%', label: 'ready'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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

class _RegressionCard extends StatelessWidget {
  const _RegressionCard({
    required this.check,
    required this.passed,
    required this.onChanged,
  });

  final _RegressionCheck check;
  final bool passed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
      borderColor: passed ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      text: check.priority,
                      color: check.priority == 'Critical'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF97316),
                    ),
                    _Badge(
                      text: check.category,
                      color: const Color(0xFF0A84FF),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  check.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  check.description,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Evidence: ${check.evidence}',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: passed, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
      ),
      child: child,
    );
  }
}
