import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../services/appointment_reminder_store.dart';
import '../services/automation_settings_store.dart';
import '../services/background_alarm_service.dart';
import '../services/do_not_send_service.dart';
import '../services/nz_recipient_store.dart';

class BackgroundServiceScreen extends StatefulWidget {
  const BackgroundServiceScreen({super.key});

  @override
  State<BackgroundServiceScreen> createState() =>
      _BackgroundServiceScreenState();
}

class _BackgroundServiceScreenState extends State<BackgroundServiceScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AutomationSettingsStore _settingsStore = AutomationSettingsStore();
  final BackgroundAlarmService _alarmService = BackgroundAlarmService();
  final DoNotSendService _doNotSend = DoNotSendService();

  List<AppointmentReminder> _queued = <AppointmentReminder>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  bool _loading = true;
  bool _busy = false;
  bool _testMode = true;
  bool _canExactAlarm = false;

  String _status = 'Background scheduler not synced yet.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();
    final testMode = await _settingsStore.loadTestMode();
    final canExactAlarm = await _alarmService.canScheduleExactAlarms();

    final queued = reminders.where((item) => !item.isSent).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _queued = queued;
      _contacts = contacts;
      _testMode = testMode;
      _canExactAlarm = canExactAlarm;
      _loading = false;
    });
  }

  NzSmsRecipient? _contactForReminder(AppointmentReminder reminder) {
    for (final contact in _contacts) {
      if (contact.id == reminder.contactId) {
        return contact;
      }
    }

    return null;
  }

  bool _allowedByTestMode(AppointmentReminder reminder) {
    if (!_testMode) {
      return true;
    }

    final contact = _contactForReminder(reminder);

    return contact?.isTestNumber == true ||
        reminder.contactName.toLowerCase().contains('test') ||
        reminder.phoneNumber == '+64211234567';
  }

  Future<void> _requestSmsPermission() async {
    setState(() => _busy = true);

    final granted = await _alarmService.requestSmsPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _status = granted
          ? 'SMS permission granted.'
          : 'SMS permission denied. Background sends will not work.';
    });
  }

  Future<void> _openExactAlarmSettings() async {
    await _alarmService.openExactAlarmSettings();
  }

  Future<void> _syncBackgroundAlarms() async {
    setState(() => _busy = true);

    final testModeAllowed = _queued.where(_allowedByTestMode).toList();
    final allowed = <AppointmentReminder>[];
    var blockedByDoNotSend = 0;

    for (final reminder in testModeAllowed) {
      final doNotSendCheck = await _doNotSend.checkReminder(reminder);

      if (doNotSendCheck.allowed) {
        allowed.add(reminder);
      } else {
        blockedByDoNotSend += 1;
        await _doNotSend.logBlocked(
          reminder: reminder,
          reason: doNotSendCheck.reason ?? 'Blocked by Do Not Send group.',
        );
      }
    }

    final blocked =
        (_queued.length - testModeAllowed.length) + blockedByDoNotSend;

    try {
      final count = await _alarmService.syncQueuedTexts(allowed);

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Synced $count background alarm(s). Blocked by Test Mode: $blocked.';
      });

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Background sync failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancelBackgroundAlarms() async {
    setState(() => _busy = true);

    try {
      await _alarmService.cancelAllBackgroundAlarms();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'All background alarms cancelled.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Cancel failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _queued.where(_allowedByTestMode).length;
    final blocked = _queued.length - allowed;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Background Scheduler'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroCard(
                  queued: _queued.length,
                  allowed: allowed,
                  blocked: blocked,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Row(
                    children: [
                      Icon(
                        _canExactAlarm
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.exclamationmark_triangle_fill,
                        color: _canExactAlarm
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF97316),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _canExactAlarm
                              ? 'Exact alarms are allowed.'
                              : 'Exact alarms may be restricted. Open settings and allow alarms for reliable background sending.',
                          style: const TextStyle(
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SurfaceCard(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _requestSmsPermission,
                  icon: const Icon(CupertinoIcons.lock_shield_fill),
                  label: const Text('Allow SMS permission'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openExactAlarmSettings,
                  icon: const Icon(CupertinoIcons.gear_alt_fill),
                  label: const Text('Open exact alarm settings'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _syncBackgroundAlarms,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.arrow_2_circlepath),
                  label: Text(_busy ? 'Working...' : 'Sync background alarms'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _cancelBackgroundAlarms,
                  icon: const Icon(CupertinoIcons.stop_fill),
                  label: const Text('Cancel background alarms'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Queued for background',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_queued.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No queued texts. Add scheduled texts in Automation first.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._queued.map(
                    (reminder) => _BackgroundQueueCard(
                      reminder: reminder,
                      dateTime: _formatDateTime(reminder.scheduledAt),
                      blocked: !_allowedByTestMode(reminder),
                    ),
                  ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Background sending uses Android AlarmManager. It can run when the app is closed, but not after the app is force-stopped from Android settings. Battery saver may delay alarms on some phones.',
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.queued,
    required this.allowed,
    required this.blocked,
  });

  final int queued;
  final int allowed;
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
            CupertinoIcons.clock_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Background sending',
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
            'Sync queued texts so Android can send them when the app is closed.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$queued', label: 'queued'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$allowed', label: 'allowed'),
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

class _BackgroundQueueCard extends StatelessWidget {
  const _BackgroundQueueCard({
    required this.reminder,
    required this.dateTime,
    required this.blocked,
  });

  final AppointmentReminder reminder;
  final String dateTime;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final color = blocked ? const Color(0xFFF97316) : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: blocked ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            blocked ? CupertinoIcons.shield_fill : CupertinoIcons.clock_fill,
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
          Text(
            blocked ? 'Blocked' : 'Ready',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
