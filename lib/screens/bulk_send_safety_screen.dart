import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/bulk_send_safety_service.dart';

class BulkSendSafetyScreen extends StatefulWidget {
  const BulkSendSafetyScreen({super.key});

  @override
  State<BulkSendSafetyScreen> createState() => _BulkSendSafetyScreenState();
}

class _BulkSendSafetyScreenState extends State<BulkSendSafetyScreen> {
  final BulkSendSafetyService _service = BulkSendSafetyService();

  BulkSendSafetyReport? _report;
  bool _loading = true;
  String _status =
      'Review batch size, rate limits, CSV risk, and live-contact guardrails before bulk sending.';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _status = 'Checking contacts and send limits...';
    });

    final report = await _service.buildReport();

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _loading = false;
      _status = report.safeForImmediateSend
          ? 'Current contact set is within basic bulk-send guardrails.'
          : 'Bulk-send guardrails need review before queueing a large batch.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Bulk Send Safety'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading || report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _BulkHero(report: report),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _MetricGrid(report: report),
                const SizedBox(height: 12),
                _GuardrailCard(
                  passed: report.consentedContacts > 0,
                  title: 'Select-all contacts / group tooling',
                  subtitle:
                      'Review consented recipients before using group queueing or select-all style workflows.',
                ),
                _GuardrailCard(
                  passed: !report.exceedsDailyLimit,
                  title: 'Rate-limit preview before queueing',
                  subtitle:
                      '${report.consentedContacts} consented recipient(s). Daily cap is ${report.maxPerDay}.',
                ),
                _GuardrailCard(
                  passed: !report.largeBatchWarning,
                  title: 'Large batch warning',
                  subtitle: report.largeBatchWarning
                      ? 'This batch is larger than the daily cap. Split it into smaller batches.'
                      : 'Batch size is within the daily safety cap.',
                ),
                _GuardrailCard(
                  passed: report.suspiciousContacts == 0,
                  title: 'Suspicious number warnings',
                  subtitle:
                      '${report.suspiciousContacts} consented contact(s) have phone-number warnings.',
                ),
                _GuardrailCard(
                  passed: true,
                  title: 'Estimated duration',
                  subtitle:
                      'At ${report.maxPerMinute} sends/minute, this batch needs about ${report.estimatedMinutes} minute(s), or ${report.estimatedHours} hour block(s) for large batches.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Preview first 25 consented contacts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (report.previewRows.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No consented contacts available for bulk-send preview.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...report.previewRows.map(_PreviewCard.new),
                const SizedBox(height: 20),
                const _SafetyNotes(),
              ],
            ),
    );
  }
}

class _BulkHero extends StatelessWidget {
  const _BulkHero({required this.report});

  final BulkSendSafetyReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.safeForImmediateSend
        ? const Color(0xFF16A34A)
        : const Color(0xFFF97316);

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
            CupertinoIcons.person_3_fill,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bulk-send safety',
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
            report.safeForImmediateSend
                ? 'Batch size, warnings, and rate limits are currently acceptable.'
                : 'Review warnings before queueing or importing a large batch.',
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
                value: '${report.consentedContacts}',
                label: 'consented',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '${report.liveContacts}',
                label: 'live',
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '${report.suspiciousContacts}',
                label: 'warnings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final BulkSendSafetyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: CupertinoIcons.person_2_fill,
          title: 'Contacts',
          value:
              '${report.totalContacts} total • ${report.consentedContacts} consented',
        ),
        _InfoCard(
          icon: CupertinoIcons.lab_flask_solid,
          title: 'Test vs live',
          value: '${report.testContacts} test • ${report.liveContacts} live',
        ),
        _InfoCard(
          icon: CupertinoIcons.timer,
          title: 'Estimated duration',
          value:
              '${report.estimatedMinutes} minute(s) at ${report.maxPerMinute}/minute',
        ),
        _InfoCard(
          icon: CupertinoIcons.speedometer,
          title: 'Rate caps',
          value:
              '${report.maxPerMinute}/minute • ${report.maxPerHour}/hour • ${report.maxPerDay}/day',
        ),
      ],
    );
  }
}

class _GuardrailCard extends StatelessWidget {
  const _GuardrailCard({
    required this.passed,
    required this.title,
    required this.subtitle,
  });

  final bool passed;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard(this.row);

  final BulkSendPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final warning = row.warning;
    final color =
        warning.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
      child: Row(
        children: [
          Icon(
            row.testMode
                ? CupertinoIcons.lab_flask_solid
                : CupertinoIcons.person_crop_circle,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.phoneNumber,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (warning.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    warning,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNotes extends StatelessWidget {
  const _SafetyNotes();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'Before sending to hundreds or thousands of recipients, split batches, confirm consent, run a small test batch, export a backup, and check carrier/SIM limits. This screen is a guardrail preview; actual send paths still enforce rate limits.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A84FF)),
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
                  value,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
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
