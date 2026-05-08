import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/appointment_reminder_store.dart';
import '../services/automation_settings_store.dart';
import '../services/background_alarm_service.dart';
import '../services/duplicate_protection_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';

class ReliabilityDashboardScreen extends StatefulWidget {
  const ReliabilityDashboardScreen({super.key});

  @override
  State<ReliabilityDashboardScreen> createState() =>
      _ReliabilityDashboardScreenState();
}

class _ReliabilityDashboardScreenState
    extends State<ReliabilityDashboardScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final SendLogStore _logStore = SendLogStore();
  final AutomationSettingsStore _settingsStore = AutomationSettingsStore();
  final BackgroundAlarmService _alarmService = BackgroundAlarmService();
  final DuplicateProtectionService _duplicateProtection =
      DuplicateProtectionService();

  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  List<SendLogEntry> _logs = <SendLogEntry>[];

  bool _loading = true;
  bool _testMode = true;
  bool _exactAlarmAllowed = false;

  String _status = 'Health check not run yet.';

  @override
  void initState() {
    super.initState();
    _runHealthCheck();
  }

  Future<void> _runHealthCheck() async {
    setState(() {
      _loading = true;
      _status = 'Running health check...';
    });

    final reminders = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();
    final logs = await _logStore.loadLogs();
    final testMode = await _settingsStore.loadTestMode();
    final exactAlarmAllowed = await _alarmService.canScheduleExactAlarms();

    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _contacts = contacts;
      _logs = logs;
      _testMode = testMode;
      _exactAlarmAllowed = exactAlarmAllowed;
      _loading = false;
      _status = 'Health check complete.';
    });
  }

  List<AppointmentReminder> get _queued {
    final items = _reminders.where((item) => !item.isSent).toList();
    items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  List<AppointmentReminder> get _due {
    final now = DateTime.now();
    return _queued.where((item) => !item.scheduledAt.isAfter(now)).toList();
  }

  List<SendLogEntry> get _last24Logs {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _logs.where((log) => log.createdAt.isAfter(cutoff)).toList();
  }

  int get _failed24 {
    return _last24Logs.where((log) => log.status == 'failed').length;
  }

  int get _blocked24 {
    return _last24Logs.where((log) => log.status == 'blocked').length;
  }

  int get _sent24 {
    return _last24Logs.where((log) => log.status == 'sent').length;
  }

  int get _testNumberCount {
    return _contacts.where((contact) => contact.isTestNumber).length;
  }

  int get _duplicateRiskCount {
    final seen = <String, int>{};

    for (final reminder in _queued) {
      final key = '${reminder.phoneNumber}|${reminder.message.trim()}';
      seen[key] = (seen[key] ?? 0) + 1;
    }

    return seen.values.where((count) => count > 1).length;
  }

  int get _overallScore {
    var score = 100;

    if (!_exactAlarmAllowed) {
      score -= 20;
    }

    if (_contacts.isEmpty) {
      score -= 15;
    }

    if (_testMode && _testNumberCount == 0) {
      score -= 15;
    }

    if (_failed24 > 0) {
      score -= 15;
    }

    if (_duplicateRiskCount > 0) {
      score -= 20;
    }

    if (_blocked24 > 0) {
      score -= 5;
    }

    return score.clamp(0, 100);
  }

  String _scoreLabel(int score) {
    if (score >= 90) {
      return 'Ready';
    }

    if (score >= 70) {
      return 'Needs review';
    }

    if (score >= 50) {
      return 'Risky';
    }

    return 'Not ready';
  }

  Color _scoreColor(int score) {
    if (score >= 90) {
      return const Color(0xFF16A34A);
    }

    if (score >= 70) {
      return const Color(0xFF0A84FF);
    }

    if (score >= 50) {
      return const Color(0xFFF97316);
    }

    return const Color(0xFFEF4444);
  }

  Future<void> _exportDebugReport() async {
    final report = StringBuffer()
      ..writeln('Text Helper Reliability Report')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('')
      ..writeln('Score: $_overallScore / 100 (${_scoreLabel(_overallScore)})')
      ..writeln('Exact alarm allowed: $_exactAlarmAllowed')
      ..writeln('Test Mode: $_testMode')
      ..writeln('Contacts: ${_contacts.length}')
      ..writeln('Test numbers: $_testNumberCount')
      ..writeln('Queued: ${_queued.length}')
      ..writeln('Due: ${_due.length}')
      ..writeln('Sent last 24h: $_sent24')
      ..writeln('Failed last 24h: $_failed24')
      ..writeln('Blocked last 24h: $_blocked24')
      ..writeln('Duplicate risks: $_duplicateRiskCount')
      ..writeln('')
      ..writeln('Queued texts:');

    for (final reminder in _queued) {
      final duplicateCheck = await _duplicateProtection.checkReminder(reminder);

      report
        ..writeln('- ${reminder.contactName}')
        ..writeln('  Number: ${reminder.phoneNumber}')
        ..writeln('  Time: ${reminder.scheduledAt.toIso8601String()}')
        ..writeln('  Duplicate allowed: ${duplicateCheck.allowed}')
        ..writeln('  Duplicate reason: ${duplicateCheck.reason ?? "none"}')
        ..writeln('  Message: ${reminder.message}');
    }

    await Clipboard.setData(ClipboardData(text: report.toString()));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug report copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scanDuplicateRisks() async {
    var blocked = 0;

    for (final reminder in _queued) {
      final result = await _duplicateProtection.checkReminder(reminder);

      if (!result.allowed) {
        blocked += 1;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _status = blocked == 0
          ? 'Duplicate scan passed. No blocked queued texts found.'
          : 'Duplicate scan found $blocked queued text(s) that would be blocked.';
    });
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final score = _overallScore;
    final scoreColor = _scoreColor(score);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Reliability'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _runHealthCheck,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ReliabilityHero(
                  score: score,
                  label: _scoreLabel(score),
                  color: scoreColor,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _scanDuplicateRisks,
                        icon: const Icon(CupertinoIcons.shield_fill),
                        label: const Text('Scan duplicates'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportDebugReport,
                        icon: const Icon(CupertinoIcons.doc_on_clipboard),
                        label: const Text('Export report'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Health checks',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _CheckCard(
                  title: 'Exact alarm permission',
                  subtitle: _exactAlarmAllowed
                      ? 'Android can schedule exact background alarms.'
                      : 'Exact alarms may be blocked. Background sends may be late or missed.',
                  passed: _exactAlarmAllowed,
                ),
                _CheckCard(
                  title: 'SMS contacts',
                  subtitle: _contacts.isEmpty
                      ? 'No contacts found.'
                      : '${_contacts.length} contact(s) available.',
                  passed: _contacts.isNotEmpty,
                ),
                _CheckCard(
                  title: 'Test Mode safety',
                  subtitle: _testMode
                      ? 'Test Mode is ON. $_testNumberCount test number(s) available.'
                      : 'Test Mode is OFF. Approved live contacts can be sent.',
                  passed: !_testMode || _testNumberCount > 0,
                ),
                _CheckCard(
                  title: 'Duplicate risk',
                  subtitle: _duplicateRiskCount == 0
                      ? 'No repeated queued number/message combinations found.'
                      : '$_duplicateRiskCount repeated queued number/message combination(s) found.',
                  passed: _duplicateRiskCount == 0,
                ),
                _CheckCard(
                  title: 'Failures last 24h',
                  subtitle: _failed24 == 0
                      ? 'No failed sends in the last 24 hours.'
                      : '$_failed24 failed send(s) in the last 24 hours.',
                  passed: _failed24 == 0,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _MetricGrid(
                  queued: _queued.length,
                  due: _due.length,
                  sent24: _sent24,
                  failed24: _failed24,
                  blocked24: _blocked24,
                  duplicateRisks: _duplicateRiskCount,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Queued texts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_queued.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No queued texts.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._queued.take(10).map(
                        (reminder) => _QueuedHealthCard(
                          reminder: reminder,
                          dateTime: _formatDateTime(reminder.scheduledAt),
                        ),
                      ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'This screen does not send texts. It checks whether the app is safe and ready before Automation or Background Scheduler sends them.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReliabilityHero extends StatelessWidget {
  const _ReliabilityHero({
    required this.score,
    required this.label,
    required this.color,
  });

  final int score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
                  color: Colors.white,
                ),
              ),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reliability score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.queued,
    required this.due,
    required this.sent24,
    required this.failed24,
    required this.blocked24,
    required this.duplicateRisks,
  });

  final int queued;
  final int due;
  final int sent24;
  final int failed24;
  final int blocked24;
  final int duplicateRisks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(value: '$queued', label: 'Queued'),
            const SizedBox(width: 12),
            _MetricCard(value: '$due', label: 'Due now'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricCard(value: '$sent24', label: 'Sent 24h'),
            const SizedBox(width: 12),
            _MetricCard(value: '$failed24', label: 'Failed 24h'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricCard(value: '$blocked24', label: 'Blocked 24h'),
            const SizedBox(width: 12),
            _MetricCard(value: '$duplicateRisks', label: 'Duplicate risks'),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _SurfaceCard(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedHealthCard extends StatelessWidget {
  const _QueuedHealthCard({
    required this.reminder,
    required this.dateTime,
  });

  final AppointmentReminder reminder;
  final String dateTime;

  @override
  Widget build(BuildContext context) {
    final due = !reminder.scheduledAt.isAfter(DateTime.now());
    final color = due ? const Color(0xFFF97316) : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: due ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            due ? CupertinoIcons.bell_fill : CupertinoIcons.clock_fill,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.contactName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateTime,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reminder.message,
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
