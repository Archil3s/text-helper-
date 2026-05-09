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
      description:
          'Home must still expose Automation, Schedule Builder, Visual Calendar, and Background Scheduler entry points.',
      area: 'Navigation',
      requiredEvidence:
          'Open Home and confirm scheduling entry points are still visible.',
    ),
    const _RegressionCheck(
      title: 'Reminder creation remains visible',
      description:
          'Users must still be able to create reminders from appointment and schedule flows after each update.',
      area: 'Reminders',
      requiredEvidence:
          'Open Visual Calendar or Automation and confirm reminder creation is reachable.',
    ),
    const _RegressionCheck(
      title: 'Background sending remains reachable',
      description:
          'Background Scheduler, Background Wizard, battery guidance, and permission checks must not disappear.',
      area: 'Background',
      requiredEvidence:
          'Open Background Scheduler and Background Wizard from Home.',
    ),
    const _RegressionCheck(
      title: 'Safety screens remain visible',
      description:
          'Recipient Audit, Bulk Send Safety, Do Not Send protections, rate limits, and Send History must remain accessible.',
      area: 'Safety',
      requiredEvidence:
          'Open Recipient Audit, Bulk Send Safety, and Send History.',
    ),
    const _RegressionCheck(
      title: 'Backup and restore remains visible',
      description:
          'Backup & Restore and Update Safety must remain reachable before any release build.',
      area: 'Data safety',
      requiredEvidence:
          'Open Backup & Restore and confirm export/import options are visible.',
    ),
    const _RegressionCheck(
      title: 'Paid/free state does not hide core SMS tools',
      description:
          'Trial, subscription, or entitlement UI must not unexpectedly hide local SMS scheduling screens.',
      area: 'Access',
      requiredEvidence:
          'Check Home while signed out/free/test state and confirm core local SMS tools remain visible.',
    ),
    const _RegressionCheck(
      title: 'Missed-call and after-call gates are explicit',
      description:
          'If missed-call or after-call features are unsupported, they must be clearly marked as roadmap or unavailable.',
      area: 'Phone features',
      requiredEvidence:
          'Confirm there is no silent hidden or half-enabled missed-call workflow.',
    ),
    const _RegressionCheck(
      title: 'Version title is visible',
      description:
          'Home should show the app version so installed test builds can be identified quickly.',
      area: 'Release QA',
      requiredEvidence:
          'Open Home and confirm the visible Text Helper title includes the app version.',
    ),
  ];

  late final List<bool> _passed =
      List<bool>.filled(_checks.length, false, growable: false);

  bool get _allPassed => _passed.every((value) => value);

  int get _passedCount => _passed.where((value) => value).length;

  Future<void> _copyChecklist() async {
    final lines = <String>[
      'Text Helper core feature regression checklist',
      '',
      for (var index = 0; index < _checks.length; index++)
        '${_passed[index] ? '[x]' : '[ ]'} ${_checks[index].title} - ${_checks[index].requiredEvidence}',
      '',
      'Release decision: ${_allPassed ? 'PASS' : 'BLOCKED'}',
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Regression checklist copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markAllPassed() {
    setState(() {
      for (var index = 0; index < _passed.length; index++) {
        _passed[index] = true;
      }
    });
  }

  void _reset() {
    setState(() {
      for (var index = 0; index < _passed.length; index++) {
        _passed[index] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _allPassed ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Core Regression Checks'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _copyChecklist,
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroCard(
            passedCount: _passedCount,
            totalCount: _checks.length,
            allPassed: _allPassed,
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
                        ? 'Core regression gate passed for this test build.'
                        : 'Release should remain blocked until all checks pass.',
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
                  onPressed: _markAllPassed,
                  icon: const Icon(CupertinoIcons.check_mark_circled),
                  label: const Text('Mark all pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Release gate checks',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _checks.length; index++)
            _RegressionCard(
              check: _checks[index],
              passed: _passed[index],
              onChanged: (value) {
                setState(() => _passed[index] = value);
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _copyChecklist,
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
            label: const Text('Copy release checklist'),
          ),
          const SizedBox(height: 12),
          const _SurfaceCard(
            child: Text(
              'Run this screen before every release branch push. If any core SMS scheduling, reminder, backup, safety, or navigation entry point disappears, stop release and fix that regression first.',
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
    required this.description,
    required this.area,
    required this.requiredEvidence,
  });

  final String title;
  final String description;
  final String area;
  final String requiredEvidence;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.passedCount,
    required this.totalCount,
    required this.allPassed,
    required this.statusColor,
  });

  final int passedCount;
  final int totalCount;
  final bool allPassed;
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
            '$passedCount/$totalCount checks passed • ${allPassed ? 'release gate passed' : 'release gate blocked'}',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
                Text(
                  check.area,
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
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
                  'Evidence: ${check.requiredEvidence}',
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
