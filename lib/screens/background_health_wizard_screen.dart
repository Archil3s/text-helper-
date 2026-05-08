import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../services/appointment_reminder_store.dart';
import '../services/background_alarm_service.dart';
import '../services/nz_recipient_store.dart';

class BackgroundHealthWizardScreen extends StatefulWidget {
  const BackgroundHealthWizardScreen({super.key});

  @override
  State<BackgroundHealthWizardScreen> createState() =>
      _BackgroundHealthWizardScreenState();
}

class _BackgroundHealthWizardScreenState
    extends State<BackgroundHealthWizardScreen> {
  final BackgroundAlarmService _alarmService = BackgroundAlarmService();
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();

  List<AppointmentReminder> _queued = <AppointmentReminder>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  bool _loading = true;
  bool _busy = false;
  bool _smsPermissionGranted = false;
  bool _smsPermissionChecked = false;
  bool _exactAlarmAllowed = false;
  bool _batteryWarningReviewed = false;
  bool _testTextQueued = false;
  bool _backgroundSynced = false;

  String _status = 'Run the wizard before relying on closed-app sending.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queued = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();
    final exactAlarmAllowed = await _alarmService.canScheduleExactAlarms();

    if (!mounted) {
      return;
    }

    setState(() {
      _queued = queued.where((item) => !item.isSent).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _contacts = contacts.where((item) => item.consented).toList();
      _exactAlarmAllowed = exactAlarmAllowed;
      _testTextQueued = _queued.any(
        (item) => item.templateName == 'Background Test',
      );
      _loading = false;
    });
  }

  NzSmsRecipient? get _testContact {
    for (final contact in _contacts) {
      if (contact.isTestNumber) {
        return contact;
      }
    }

    return null;
  }

  int get _completedSteps {
    var count = 0;

    if (_smsPermissionGranted) {
      count += 1;
    }

    if (_exactAlarmAllowed) {
      count += 1;
    }

    if (_batteryWarningReviewed) {
      count += 1;
    }

    if (_testTextQueued) {
      count += 1;
    }

    if (_backgroundSynced) {
      count += 1;
    }

    return count;
  }

  bool get _ready => _completedSteps == 5;

  Future<void> _requestSmsPermission() async {
    setState(() {
      _busy = true;
      _status = 'Requesting SMS permission...';
    });

    final granted = await _alarmService.requestSmsPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _smsPermissionChecked = true;
      _smsPermissionGranted = granted;
      _busy = false;
      _status = granted
          ? 'SMS permission is allowed.'
          : 'SMS permission is blocked. Background SMS cannot send.';
    });
  }

  Future<void> _openExactAlarmSettings() async {
    await _alarmService.openExactAlarmSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'After changing alarm settings, return here and tap Refresh status.';
    });
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _busy = true;
      _status = 'Refreshing background health status...';
    });

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _status = 'Status refreshed.';
    });
  }

  Future<void> _queueTestText() async {
    final contact = _testContact;

    if (contact == null) {
      setState(() {
        _status =
            'Add a contact marked as Test Number first. The wizard will not queue live contacts.';
      });
      return;
    }

    final scheduledAt = DateTime.now().add(const Duration(minutes: 2));

    await _reminderStore.addReminder(
      AppointmentReminder(
        id: 'background-test-${DateTime.now().millisecondsSinceEpoch}',
        contactId: contact.id,
        phoneNumber: contact.number,
        appointmentTitle: 'Background test',
        location: '',
        message:
            'Text Helper background test. If you receive this, closed-app scheduling is working.',
        scheduledAt: scheduledAt,
        isSent: false,
        recurrenceRule: 'once',
        templateName: 'Background Test',
        notes: 'Created by Background Health Wizard',
      ),
    );

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _testTextQueued = true;
      _status =
          'Background test text queued for ${_formatDateTime(scheduledAt)}.';
    });
  }

  Future<void> _syncBackgroundAlarms() async {
    setState(() {
      _busy = true;
      _status = 'Syncing queued texts to Android background alarms...';
    });

    try {
      final queued = await _reminderStore.loadReminders();
      final unsent = queued.where((item) => !item.isSent).toList();
      final count = await _alarmService.syncQueuedTexts(unsent);

      if (!mounted) {
        return;
      }

      setState(() {
        _backgroundSynced = true;
        _busy = false;
        _status =
            'Synced $count background alarm(s). You can now close the app.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _status = 'Background sync failed: $error';
      });
    }
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completedSteps / 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Background Wizard'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _busy ? null : _refreshStatus,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _WizardHero(
                  completed: _completedSteps,
                  ready: _ready,
                  progress: progress,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                _WizardStepCard(
                  stepNumber: 1,
                  title: 'Allow SMS permission',
                  subtitle:
                      'Required so Android can send scheduled SMS messages.',
                  complete: _smsPermissionGranted,
                  warning: _smsPermissionChecked && !_smsPermissionGranted,
                  buttonLabel: 'Allow SMS permission',
                  onPressed: _busy ? null : _requestSmsPermission,
                ),
                _WizardStepCard(
                  stepNumber: 2,
                  title: 'Allow exact alarms',
                  subtitle:
                      'Required for reliable closed-app background scheduling.',
                  complete: _exactAlarmAllowed,
                  warning: !_exactAlarmAllowed,
                  buttonLabel: _exactAlarmAllowed
                      ? 'Exact alarms allowed'
                      : 'Open alarm settings',
                  onPressed: _busy || _exactAlarmAllowed
                      ? null
                      : _openExactAlarmSettings,
                ),
                _WizardStepCard(
                  stepNumber: 3,
                  title: 'Review battery warning',
                  subtitle:
                      'Battery saver can delay or stop background alarms on some phones. Keep Text Helper unrestricted if possible.',
                  complete: _batteryWarningReviewed,
                  warning: !_batteryWarningReviewed,
                  buttonLabel: 'I reviewed this',
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _batteryWarningReviewed = true;
                            _status = 'Battery warning reviewed.';
                          });
                        },
                ),
                _WizardStepCard(
                  stepNumber: 4,
                  title: 'Queue a test text',
                  subtitle: _testContact == null
                      ? 'Add a Test Number contact before running this step.'
                      : 'Queues one test SMS to ${_testContact!.number}.',
                  complete: _testTextQueued,
                  warning: _testContact == null,
                  buttonLabel: 'Queue test text',
                  onPressed: _busy || _testTextQueued ? null : _queueTestText,
                ),
                _WizardStepCard(
                  stepNumber: 5,
                  title: 'Sync background alarms',
                  subtitle:
                      'Sends queued texts to Android AlarmManager so they can trigger when the app is closed.',
                  complete: _backgroundSynced,
                  warning: !_backgroundSynced,
                  buttonLabel: 'Sync background alarms',
                  onPressed: _busy ? null : _syncBackgroundAlarms,
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Text(
                    _ready
                        ? 'Background setup is complete. Close the app and wait for the test SMS.'
                        : 'Complete all steps before relying on closed-app sends.',
                    style: TextStyle(
                      color: _ready
                          ? const Color(0xFF16A34A)
                          : CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Text(
                    'Important: Android will not run background alarms if the app is force-stopped from system settings. Some phones may delay alarms while battery saver is active.',
                    style: const TextStyle(
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

class _WizardHero extends StatelessWidget {
  const _WizardHero({
    required this.completed,
    required this.ready,
    required this.progress,
  });

  final int completed;
  final bool ready;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8);

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
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
                  color: Colors.white,
                ),
              ),
              Text(
                '$completed/5',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
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
                  'Background setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ready
                      ? 'Ready for closed-app background tests.'
                      : 'Complete each step before depending on background sends.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
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

class _WizardStepCard extends StatelessWidget {
  const _WizardStepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.warning,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int stepNumber;
  final String title;
  final String subtitle;
  final bool complete;
  final bool warning;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? const Color(0xFF16A34A)
        : warning
            ? const Color(0xFFF97316)
            : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: complete ? null : color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: complete
                    ? Icon(
                        CupertinoIcons.check_mark,
                        color: color,
                        size: 18,
                      )
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              complete
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.arrow_right_circle,
              size: 16,
            ),
            label: Text(buttonLabel),
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
