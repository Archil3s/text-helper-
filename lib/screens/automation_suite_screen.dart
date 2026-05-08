import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/appointment_reminder_store.dart';
import '../services/automation_settings_store.dart';
import '../services/native_sms_service.dart';
import '../services/duplicate_protection_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';

class AutomationSuiteScreen extends StatefulWidget {
  const AutomationSuiteScreen({super.key});

  @override
  State<AutomationSuiteScreen> createState() => _AutomationSuiteScreenState();
}

class _AutomationSuiteScreenState extends State<AutomationSuiteScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final AutomationSettingsStore _settingsStore = AutomationSettingsStore();
  final NativeSmsService _smsService = NativeSmsService();
  final SendLogStore _logStore = SendLogStore();
  final DuplicateProtectionService _duplicateProtection =
      DuplicateProtectionService();

  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  Timer? _timer;

  bool _loading = true;
  bool _running = false;
  bool _sending = false;
  bool _testMode = true;

  String _status = 'Queue stopped';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final reminders = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();
    final testMode = await _settingsStore.loadTestMode();

    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _contacts = contacts.where((item) => item.consented).toList();
      _testMode = testMode;
      _loading = false;
    });
  }

  List<AppointmentReminder> get _queuedReminders {
    final items = _reminders.where((item) => !item.isSent).toList();
    items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  List<AppointmentReminder> get _sentReminders {
    final items = _reminders.where((item) => item.isSent).toList();
    items.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return items;
  }

  List<AppointmentReminder> get _dueReminders {
    final now = DateTime.now();

    return _queuedReminders
        .where((item) => !item.scheduledAt.isAfter(now))
        .toList();
  }

  DateTime _nextSchedule(DateTime current, String rule) {
    return switch (rule) {
      'everyMinute' => current.add(const Duration(minutes: 1)),
      'daily' => current.add(const Duration(days: 1)),
      'weekly' => current.add(const Duration(days: 7)),
      'monthly' => DateTime(
          current.year,
          current.month + 1,
          current.day,
          current.hour,
          current.minute,
        ),
      _ => current,
    };
  }

  String _ruleLabel(String rule) {
    return switch (rule) {
      'everyMinute' => 'Every minute',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      _ => 'Once',
    };
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} ${_formatTime(value)}';
  }

  String _templateMessage({
    required String template,
    required String name,
    required String title,
    required String location,
    required DateTime scheduledAt,
  }) {
    final time = _formatTime(scheduledAt);
    final place = location.trim().isEmpty ? '' : ' at $location';

    return switch (template) {
      'Confirmation' =>
        'Hi $name, please confirm your $title appointment at $time$place. Reply YES to confirm.',
      'Follow up' =>
        'Hi $name, following up about your $title appointment. Please reply when you can.',
      'Payment reminder' =>
        'Hi $name, reminder that payment may be due for your $title appointment. Thank you.',
      'Running late' =>
        'Hi $name, this is a quick update about your $title appointment. We may be running slightly late.',
      _ => 'Hi $name, reminder for your $title appointment at $time$place.',
    };
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

    if (contact?.isTestNumber == true) {
      return true;
    }

    if (reminder.contactName.toLowerCase().contains('test')) {
      return true;
    }

    if (reminder.phoneNumber == '+64211234567') {
      return true;
    }

    return false;
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addOrEditQueuedText({AppointmentReminder? existing}) async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an approved contact first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    NzSmsRecipient selectedContact = _contacts.first;

    if (existing != null) {
      for (final contact in _contacts) {
        if (contact.id == existing.contactId) {
          selectedContact = contact;
          break;
        }
      }
    }

    var scheduledAt =
        existing?.scheduledAt ?? DateTime.now().add(const Duration(minutes: 5));

    var repeat = existing?.recurrenceRule ?? 'once';
    var template = existing?.templateName ?? 'Appointment reminder';

    final titleController = TextEditingController(
      text: existing?.appointmentTitle ?? 'Appointment',
    );
    final locationController = TextEditingController(
      text: existing?.location ?? '',
    );
    final notesController = TextEditingController(
      text: existing?.notes ?? '',
    );
    final messageController = TextEditingController(
      text: existing?.message ??
          _templateMessage(
            template: template,
            name: selectedContact.name,
            title: 'Appointment',
            location: '',
            scheduledAt: scheduledAt,
          ),
    );

    void rebuildMessage() {
      messageController.text = _templateMessage(
        template: template,
        name: selectedContact.name,
        title: titleController.text.trim().isEmpty
            ? 'Appointment'
            : titleController.text.trim(),
        location: locationController.text.trim(),
        scheduledAt: scheduledAt,
      );
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: scheduledAt,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );

              if (picked == null) {
                return;
              }

              setSheetState(() {
                scheduledAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  scheduledAt.hour,
                  scheduledAt.minute,
                );
                rebuildMessage();
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(scheduledAt),
              );

              if (picked == null) {
                return;
              }

              setSheetState(() {
                scheduledAt = DateTime(
                  scheduledAt.year,
                  scheduledAt.month,
                  scheduledAt.day,
                  picked.hour,
                  picked.minute,
                );
                rebuildMessage();
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey3,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        existing == null
                            ? 'Queue scheduled text'
                            : 'Edit queued text',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<NzSmsRecipient>(
                        initialValue: selectedContact,
                        decoration: _fieldDecoration('Contact'),
                        items: _contacts
                            .map(
                              (item) => DropdownMenuItem<NzSmsRecipient>(
                                value: item,
                                child:
                                    Text('${item.name} Ã¢â‚¬Â¢ ${item.number}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            selectedContact = value;
                            rebuildMessage();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: _fieldDecoration('Appointment / text type'),
                        onChanged: (_) => setSheetState(rebuildMessage),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: _fieldDecoration('Location / detail'),
                        onChanged: (_) => setSheetState(rebuildMessage),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: template,
                        decoration: _fieldDecoration('Template'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Appointment reminder',
                            child: Text('Appointment reminder'),
                          ),
                          DropdownMenuItem(
                            value: 'Confirmation',
                            child: Text('Confirmation request'),
                          ),
                          DropdownMenuItem(
                            value: 'Follow up',
                            child: Text('Follow up'),
                          ),
                          DropdownMenuItem(
                            value: 'Payment reminder',
                            child: Text('Payment reminder'),
                          ),
                          DropdownMenuItem(
                            value: 'Running late',
                            child: Text('Running late'),
                          ),
                          DropdownMenuItem(
                            value: 'Custom',
                            child: Text('Custom'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            template = value;
                            if (template != 'Custom') {
                              rebuildMessage();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: repeat,
                        decoration: _fieldDecoration('Repeat'),
                        items: const [
                          DropdownMenuItem(value: 'once', child: Text('Once')),
                          DropdownMenuItem(
                            value: 'everyMinute',
                            child: Text('Every minute test'),
                          ),
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() => repeat = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDate,
                              icon: const Icon(CupertinoIcons.calendar),
                              label: const Text('Date'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickTime,
                              icon: const Icon(CupertinoIcons.clock),
                              label: const Text('Time'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MiniInfoCard(
                        icon: CupertinoIcons.clock_fill,
                        title: 'Scheduled',
                        value: _formatDateTime(scheduledAt),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: _fieldDecoration('Text message'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: _fieldDecoration('Internal notes'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(CupertinoIcons.check_mark),
                        label: const Text('Save to queue'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final message = messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    final reminder = AppointmentReminder(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      contactId: selectedContact.id,
      contactName: selectedContact.name,
      phoneNumber: selectedContact.number,
      appointmentTitle: titleController.text.trim().isEmpty
          ? 'Scheduled text'
          : titleController.text.trim(),
      location: locationController.text.trim(),
      message: message,
      scheduledAt: scheduledAt,
      isSent: false,
      recurrenceRule: repeat,
      templateName: template,
      notes: notesController.text.trim(),
    );

    if (existing == null) {
      await _reminderStore.addReminder(reminder);
    } else {
      await _reminderStore.updateReminder(reminder);
    }

    await _load();
  }

  Future<void> _duplicateQueuedText(AppointmentReminder reminder) async {
    await _reminderStore.addReminder(
      reminder.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
        isSent: false,
        sentAt: null,
      ),
    );

    await _load();
  }

  Future<void> _resetQueuedText(AppointmentReminder reminder) async {
    await _reminderStore.updateReminder(
      reminder.copyWith(
        isSent: false,
        sentAt: null,
      ),
    );

    await _load();
  }

  Future<void> _deleteQueuedText(AppointmentReminder reminder) async {
    await _reminderStore.deleteReminder(reminder.id);
    await _load();
  }

  Future<void> _logSend(
    AppointmentReminder reminder,
    String status,
    String? error,
  ) async {
    await _logStore.addLog(
      SendLogEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        contactName: reminder.contactName,
        phoneNumber: reminder.phoneNumber,
        message: reminder.message,
        createdAt: DateTime.now(),
        status: status,
        errorMessage: error,
        reminderId: reminder.id,
      ),
    );
  }

  Future<void> _sendReminder(AppointmentReminder reminder) async {
    if (!_allowedByTestMode(reminder)) {
      await _logSend(reminder, 'blocked', 'Blocked by Test Mode');

      setState(() {
        _status = 'Blocked by Test Mode: ${reminder.contactName}';
      });

      return;
    }

    final duplicateCheck = await _duplicateProtection.checkReminder(reminder);
    if (!duplicateCheck.allowed) {
      final reason = duplicateCheck.reason ?? 'Blocked duplicate send.';
      await _duplicateProtection.logBlockedDuplicate(
        reminder: reminder,
        reason: reason,
      );

      if (mounted) {
        setState(() {
          _status = reason;
        });
      }

      return;
    }
    await _smsService.sendSms(
      phoneNumber: reminder.phoneNumber,
      message: reminder.message,
    );

    await _logSend(reminder, 'sent', null);

    await _reminderStore.updateReminder(
      reminder.copyWith(
        isSent: true,
        sentAt: DateTime.now(),
      ),
    );

    if (reminder.recurrenceRule != 'once') {
      await _reminderStore.addReminder(
        reminder.copyWith(
          id: '${DateTime.now().millisecondsSinceEpoch}-${reminder.id}',
          scheduledAt: _nextSchedule(
            reminder.scheduledAt,
            reminder.recurrenceRule,
          ),
          isSent: false,
          sentAt: null,
        ),
      );
    }
  }

  Future<void> _sendDueNow() async {
    if (_sending) {
      return;
    }

    final due = _dueReminders;

    if (due.isEmpty) {
      setState(() => _status = 'No due texts in queue.');
      return;
    }

    setState(() {
      _sending = true;
      _status = 'Sending ${due.length} due queued text(s)...';
    });

    for (final reminder in due) {
      try {
        await _sendReminder(reminder);
      } catch (error) {
        await _logSend(reminder, 'failed', error.toString());

        if (!mounted) {
          return;
        }

        setState(() => _status = 'Send failed: $error');
      }
    }

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _sending = false;
      _status = 'Due queue processed.';
    });
  }

  void _startQueueRunner() {
    _timer?.cancel();

    setState(() {
      _running = true;
      _status = 'Queue runner active. App must stay open.';
    });

    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendDueNow(),
    );
  }

  void _forceStop() {
    _timer?.cancel();

    setState(() {
      _running = false;
      _sending = false;
      _status = 'Force stopped.';
    });
  }

  Future<void> _toggleTestMode(bool value) async {
    await _settingsStore.saveTestMode(value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final queued = _queuedReminders;
    final due = _dueReminders;
    final sent = _sentReminders;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Automation'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: () => _addOrEditQueuedText(),
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditQueuedText(),
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Queue text'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _AutomationHero(
                  isRunning: _running,
                  queuedCount: queued.length,
                  dueCount: due.length,
                  sentCount: sent.length,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: SwitchListTile(
                    value: _testMode,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Test Mode Safety',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'ON blocks sends unless the contact is marked as a test number.',
                    ),
                    onChanged: _toggleTestMode,
                  ),
                ),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _sending ? null : _sendDueNow,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(_sending ? 'Sending...' : 'Send due now'),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _running ? null : _startQueueRunner,
                        icon: const Icon(CupertinoIcons.play_fill),
                        label: const Text('Start queue'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _running ? _forceStop : null,
                        icon: const Icon(CupertinoIcons.stop_fill),
                        label: const Text('Force stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionHeader(
                  title: 'Queued texts',
                  count: queued.length,
                  actionLabel: 'Add',
                  onAction: () => _addOrEditQueuedText(),
                ),
                const SizedBox(height: 12),
                if (queued.isEmpty)
                  _EmptyQueueCard(onAdd: () => _addOrEditQueuedText())
                else
                  ...queued.map(
                    (reminder) => _QueuedTextCard(
                      reminder: reminder,
                      dateTime: _formatDateTime(reminder.scheduledAt),
                      repeat: _ruleLabel(reminder.recurrenceRule),
                      isDue: !reminder.scheduledAt.isAfter(DateTime.now()),
                      onEdit: () => _addOrEditQueuedText(existing: reminder),
                      onDuplicate: () => _duplicateQueuedText(reminder),
                      onReset: () => _resetQueuedText(reminder),
                      onDelete: () => _deleteQueuedText(reminder),
                    ),
                  ),
                const SizedBox(height: 22),
                _SectionHeader(
                  title: 'Recently sent',
                  count: sent.length,
                ),
                const SizedBox(height: 12),
                if (sent.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No sent texts yet.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...sent.take(5).map(
                        (reminder) => _SentTextCard(
                          reminder: reminder,
                          dateTime: _formatDateTime(
                            reminder.sentAt ?? reminder.scheduledAt,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }
}

class _AutomationHero extends StatelessWidget {
  const _AutomationHero({
    required this.isRunning,
    required this.queuedCount,
    required this.dueCount,
    required this.sentCount,
  });

  final bool isRunning;
  final int queuedCount;
  final int dueCount;
  final int sentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning
              ? const [Color(0xFF0A84FF), Color(0xFF1D4ED8)]
              : const [Color(0xFF111827), Color(0xFF374151)],
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
          Icon(
            isRunning
                ? CupertinoIcons.play_circle_fill
                : CupertinoIcons.gear_alt_fill,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          Text(
            isRunning ? 'Automation running' : 'Text automation queue',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule, queue, and send all reminder texts from here.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$queuedCount', label: 'queued'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$dueCount', label: 'due'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$sentCount', label: 'sent'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF0A84FF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _QueuedTextCard extends StatelessWidget {
  const _QueuedTextCard({
    required this.reminder,
    required this.dateTime,
    required this.repeat,
    required this.isDue,
    required this.onEdit,
    required this.onDuplicate,
    required this.onReset,
    required this.onDelete,
  });

  final AppointmentReminder reminder;
  final String dateTime;
  final String repeat;
  final bool isDue;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = isDue ? const Color(0xFFF97316) : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: isDue ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onEdit,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    isDue
                        ? CupertinoIcons.bell_fill
                        : CupertinoIcons.clock_fill,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.contactName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
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
                      const SizedBox(height: 4),
                      Text(
                        reminder.appointmentTitle,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder.message,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _Chip(
                  label: isDue ? 'Due' : 'Queued',
                  color: color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: repeat, color: const Color(0xFF111827)),
              _Chip(
                  label: reminder.templateName, color: const Color(0xFF6B7280)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil, size: 16),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                label: const Text('Duplicate'),
              ),
              OutlinedButton.icon(
                onPressed: onReset,
                icon:
                    const Icon(CupertinoIcons.arrow_counterclockwise, size: 16),
                label: const Text('Reset'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentTextCard extends StatelessWidget {
  const _SentTextCard({
    required this.reminder,
    required this.dateTime,
  });

  final AppointmentReminder reminder;
  final String dateTime;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Color(0xFF16A34A),
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
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w700,
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

class _EmptyQueueCard extends StatelessWidget {
  const _EmptyQueueCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.tray,
            color: Color(0xFF0A84FF),
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'No queued texts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Schedule your first reminder text here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(CupertinoIcons.plus),
            label: const Text('Queue text'),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
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
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
