import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/update_safe_migration_service.dart';

class UpdateSafeMigrationScreen extends StatefulWidget {
  const UpdateSafeMigrationScreen({super.key});

  @override
  State<UpdateSafeMigrationScreen> createState() =>
      _UpdateSafeMigrationScreenState();
}

class _UpdateSafeMigrationScreenState extends State<UpdateSafeMigrationScreen> {
  static const String _appVersion = '0.1.0+1';

  final UpdateSafeMigrationService _service = UpdateSafeMigrationService();

  UpdateSafeMigrationReport? _report;
  bool _loading = true;
  String _status =
      'Check local data before updates, reinstalls, and APK replacements.';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _status = 'Checking migration and update safety...';
    });

    final report = await _service.buildReport(currentAppVersion: _appVersion);

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _loading = false;
      _status = report.warnings.isEmpty
          ? 'No migration warnings found.'
          : 'Review migration warnings before updating.';
    });
  }

  Future<void> _recordState() async {
    await _service.recordCurrentState(currentAppVersion: _appVersion);
    await _refresh();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Current version and data counts recorded.';
    });
  }

  Future<void> _copyBackup() async {
    final backupJson = await _service.buildBackupJsonAndRecordPrompt();
    await Clipboard.setData(ClipboardData(text: backupJson));

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Backup JSON copied to clipboard.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Update Safety'),
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
                _UpdateHero(report: report),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _MetricGrid(report: report),
                const SizedBox(height: 12),
                _GuardrailCard(
                  passed: report.schemaVersion >=
                      UpdateSafeMigrationService.currentSchemaVersion,
                  title: 'Versioned local data migrations',
                  subtitle:
                      'Current schema ${UpdateSafeMigrationService.currentSchemaVersion}. Stored schema ${report.schemaVersion}.',
                ),
                _GuardrailCard(
                  passed: !report.backupRecommended,
                  title: 'Pre-update backup reminder',
                  subtitle: report.backupRecommended
                      ? 'Backup recommended before installing another APK.'
                      : 'No backup reminder needed right now.',
                ),
                _GuardrailCard(
                  passed: !report.restorePromptRecommended,
                  title: 'Empty data detection',
                  subtitle: report.restorePromptRecommended
                      ? 'Previously detected data now looks empty. Restore may be needed.'
                      : 'No unexpected empty contacts or reminders detected.',
                ),
                _GuardrailCard(
                  passed: report.unsentRemindersCount == 0,
                  title: 'Scheduled reminder protection',
                  subtitle:
                      '${report.unsentRemindersCount} unsent reminder(s) are stored.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _copyBackup,
                  icon: const Icon(CupertinoIcons.doc_on_clipboard),
                  label: const Text('Copy backup before update'),
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
                  onPressed: _recordState,
                  icon: const Icon(CupertinoIcons.check_mark_circled),
                  label: const Text('Record current safe state'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Warnings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (report.warnings.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No warnings found.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...report.warnings.map(
                    (warning) => _WarningCard(warning: warning),
                  ),
              ],
            ),
    );
  }
}

class _UpdateHero extends StatelessWidget {
  const _UpdateHero({required this.report});

  final UpdateSafeMigrationReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.warnings.isEmpty
        ? const Color(0xFF16A34A)
        : const Color(0xFFF97316);

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
          const Icon(CupertinoIcons.arrow_2_circlepath,
              color: Colors.white, size: 36),
          const SizedBox(height: 16),
          const Text(
            'Update-safe checks',
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
            'Protect contacts, reminders, and scheduled sends across APK updates.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '${report.contactsCount}', label: 'contacts'),
              const SizedBox(width: 10),
              _HeroMetric(
                  value: '${report.remindersCount}', label: 'reminders'),
              const SizedBox(width: 10),
              _HeroMetric(
                  value: '${report.warnings.length}', label: 'warnings'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final UpdateSafeMigrationReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: CupertinoIcons.device_phone_portrait,
          title: 'App version',
          value:
              'Current ${report.currentAppVersion} - Previous ${report.lastAppVersion}',
        ),
        _InfoCard(
          icon: CupertinoIcons.archivebox_fill,
          title: 'Local data',
          value:
              '${report.contactsCount} contacts - ${report.remindersCount} reminders',
        ),
        _InfoCard(
          icon: CupertinoIcons.clock_fill,
          title: 'Scheduled sends',
          value: '${report.unsentRemindersCount} unsent reminder(s)',
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final String warning;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFF97316),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warning,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
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
                Text(title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    )),
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
                Text(title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    )),
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
