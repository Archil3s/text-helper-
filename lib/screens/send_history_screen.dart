import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/automation_settings_store.dart';
import '../services/delivery_status_mapper.dart';
import '../services/duplicate_protection_service.dart';
import '../services/native_sms_service.dart';
import '../services/do_not_send_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/rate_limit_service.dart';
import '../services/send_log_store.dart';

class SendHistoryScreen extends StatefulWidget {
  const SendHistoryScreen({super.key});

  @override
  State<SendHistoryScreen> createState() => _SendHistoryScreenState();
}

class _SendHistoryScreenState extends State<SendHistoryScreen> {
  final SendLogStore _logStore = SendLogStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AutomationSettingsStore _settingsStore = AutomationSettingsStore();
  final NativeSmsService _smsService = NativeSmsService();
  final DuplicateProtectionService _duplicateProtection =
      DuplicateProtectionService();
  final RateLimitService _rateLimit = RateLimitService();
  final DoNotSendService _doNotSend = DoNotSendService();

  List<SendLogEntry> _logs = <SendLogEntry>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  bool _loading = true;
  bool _retrying = false;
  bool _testMode = true;

  String _status = 'Send history loaded.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _logStore.loadLogs();
    final contacts = await _recipientStore.loadRecipients();
    final testMode = await _settingsStore.loadTestMode();

    if (!mounted) {
      return;
    }

    setState(() {
      _logs = logs;
      _contacts = contacts;
      _testMode = testMode;
      _loading = false;
    });
  }

  List<SendLogEntry> get _failedLogs {
    return _logs
        .where((log) => DeliveryStatusMapper.isFailed(log.status))
        .toList();
  }

  List<SendLogEntry> get _blockedLogs {
    return _logs
        .where((log) => DeliveryStatusMapper.isBlocked(log.status))
        .toList();
  }

  List<SendLogEntry> get _sentLogs {
    return _logs
        .where((log) => DeliveryStatusMapper.isSentToAndroid(log.status))
        .toList();
  }

  NzSmsRecipient? _contactForNumber(String phoneNumber) {
    for (final contact in _contacts) {
      if (contact.number == phoneNumber) {
        return contact;
      }
    }

    return null;
  }

  bool _allowedByTestMode(SendLogEntry log) {
    if (!_testMode) {
      return true;
    }

    final contact = _contactForNumber(log.phoneNumber);

    if (contact?.isTestNumber == true) {
      return true;
    }

    if (log.phoneNumber == '+64211234567') {
      return true;
    }

    return false;
  }

  AppointmentReminder _retryReminderFromLog(SendLogEntry log) {
    final contact = _contactForNumber(log.phoneNumber);

    return AppointmentReminder(
      id: 'retry-${DateTime.now().microsecondsSinceEpoch}-${log.id}',
      contactId: contact?.id ?? '',
      phoneNumber: log.phoneNumber,
      appointmentTitle: 'Retry failed send',
      location: '',
      message: log.message,
      scheduledAt: DateTime.now(),
      isSent: false,
      recurrenceRule: 'once',
      templateName: 'Retry',
      notes: 'Retried from failed send log ${log.id}',
    );
  }

  Future<void> _logRetryResult({
    required SendLogEntry sourceLog,
    required String status,
    String? errorMessage,
  }) async {
    await _logStore.addLog(
      SendLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        phoneNumber: sourceLog.phoneNumber,
        message: sourceLog.message,
        createdAt: DateTime.now(),
        status: status,
        errorMessage: errorMessage,
        reminderId: sourceLog.reminderId,
      ),
    );
  }

  Future<bool> _retryLog(SendLogEntry log) async {
    if (!_allowedByTestMode(log)) {
      await _logRetryResult(
        sourceLog: log,
        status: 'blocked',
        errorMessage: 'Retry blocked by Test Mode.',
      );
      return false;
    }

    final retryReminder = _retryReminderFromLog(log);
    final doNotSendCheck = await _doNotSend.checkReminder(retryReminder);
    if (!doNotSendCheck.allowed) {
      final reason =
          doNotSendCheck.reason ?? 'Retry blocked by Do Not Send group.';
      await _doNotSend.logBlocked(
        reminder: retryReminder,
        reason: reason,
      );
      return false;
    }

    final rateLimitCheck = await _rateLimit.check(retryReminder);
    if (!rateLimitCheck.allowed) {
      final reason = rateLimitCheck.reason ?? 'Retry blocked by rate limit.';

      await _rateLimit.logBlockedRateLimit(
        reminder: retryReminder,
        reason: reason,
      );

      return false;
    }

    final duplicateCheck =
        await _duplicateProtection.checkReminder(retryReminder);
    if (!duplicateCheck.allowed) {
      final reason = duplicateCheck.reason ?? 'Retry blocked as duplicate.';

      await _duplicateProtection.logBlockedDuplicate(
        reminder: retryReminder,
        reason: reason,
      );

      return false;
    }

    try {
      await _smsService.sendSms(
        phoneNumber: log.phoneNumber,
        message: log.message,
      );

      await _logRetryResult(
        sourceLog: log,
        status: 'sent',
      );

      return true;
    } catch (error) {
      await _logRetryResult(
        sourceLog: log,
        status: 'failed',
        errorMessage: error.toString(),
      );

      return false;
    }
  }

  Future<void> _retryOne(SendLogEntry log) async {
    if (_retrying) {
      return;
    }

    setState(() {
      _retrying = true;
      _status = 'Retrying failed send...';
    });

    final success = await _retryLog(log);
    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _retrying = false;
      _status = success ? 'Retry sent.' : 'Retry blocked or failed.';
    });
  }

  Future<void> _retryAllFailed() async {
    if (_retrying) {
      return;
    }

    final failed = _failedLogs;

    if (failed.isEmpty) {
      setState(() => _status = 'No failed sends to retry.');
      return;
    }

    setState(() {
      _retrying = true;
      _status = 'Retrying ${failed.length} failed send(s)...';
    });

    var sent = 0;
    var blockedOrFailed = 0;

    for (final log in failed) {
      final success = await _retryLog(log);

      if (success) {
        sent += 1;
      } else {
        blockedOrFailed += 1;
      }
    }

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _retrying = false;
      _status =
          'Retry complete. Sent: $sent. Blocked/failed: $blockedOrFailed.';
    });
  }

  Future<void> _clear() async {
    await _logStore.clearLogs();
    await _load();
  }

  String _format(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Color _color(String status) {
    return DeliveryStatusMapper.color(status);
  }

  IconData _icon(String status) {
    return DeliveryStatusMapper.icon(status);
  }

  @override
  Widget build(BuildContext context) {
    final failedCount = _failedLogs.length;
    final blockedCount = _blockedLogs.length;
    final sentCount = _sentLogs.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Send History'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _retrying ? null : _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _retrying ? null : _clear,
            icon: const Icon(CupertinoIcons.trash),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HistoryHero(
                  total: _logs.length,
                  sent: sentCount,
                  failed: failedCount,
                  blocked: blockedCount,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.info_circle_fill,
                        color: Color(0xFF0A84FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
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
                FilledButton.icon(
                  onPressed:
                      _retrying || failedCount == 0 ? null : _retryAllFailed,
                  icon: _retrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.arrow_clockwise),
                  label: Text(
                    _retrying
                        ? 'Retrying...'
                        : 'Retry all failed ($failedCount)',
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
                _SurfaceCard(
                  child: Text(
                    _testMode
                        ? 'Test Mode is ON. Retry will only send to contacts marked as test numbers.'
                        : 'Test Mode is OFF. Retry can send to approved live contacts.',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Logs',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_logs.isEmpty)
                  const _SurfaceCard(child: Text('No logs yet.'))
                else
                  ..._logs.map(
                    (log) => _LogCard(
                      log: log,
                      color: _color(log.status),
                      icon: _icon(log.status),
                      dateTime: _format(log.createdAt),
                      onRetry: log.status == 'failed' && !_retrying
                          ? () => _retryOne(log)
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HistoryHero extends StatelessWidget {
  const _HistoryHero({
    required this.total,
    required this.sent,
    required this.failed,
    required this.blocked,
  });

  final int total;
  final int sent;
  final int failed;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
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
            CupertinoIcons.doc_text_search,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Send history',
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
            'Review Android-accepted, delivered, failed, blocked, and retryable messages.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$total', label: 'total'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$sent', label: 'sent'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$failed', label: 'failed'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$blocked', label: 'blocked'),
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

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.color,
    required this.icon,
    required this.dateTime,
    required this.onRetry,
  });

  final SendLogEntry log;
  final Color color;
  final IconData icon;
  final String dateTime;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: log.status == 'failed' ? color : null,
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
                  log.phoneNumber,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateTime,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  log.message,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (log.errorMessage != null &&
                    log.errorMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    log.errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
          Text(
            DeliveryStatusMapper.label(log.status).toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
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
