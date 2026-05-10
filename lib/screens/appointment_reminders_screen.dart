import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../services/appointment_reminder_store.dart';
import '../services/native_sms_service.dart';
import '../services/nz_recipient_store.dart';

class AppointmentRemindersScreen extends StatefulWidget {
  const AppointmentRemindersScreen({super.key});

  @override
  State<AppointmentRemindersScreen> createState() =>
      _AppointmentRemindersScreenState();
}

class _AppointmentRemindersScreenState
    extends State<AppointmentRemindersScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final NativeSmsService _smsService = NativeSmsService();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  List<AppointmentReminder> _reminders = <AppointmentReminder>[];

  Timer? _schedulerTimer;

  bool _isLoading = true;
  bool _schedulerRunning = false;
  bool _isSending = false;

  String _status = 'Scheduler stopped';

  int get _pendingCount {
    return _reminders.where((reminder) => !reminder.isSent).length;
  }

  int get _dueCount {
    final now = DateTime.now();
    return _reminders
        .where((reminder) =>
            !reminder.isSent && !reminder.scheduledAt.isAfter(now))
        .length;
  }

  int get _sentCount {
    return _reminders.where((reminder) => reminder.isSent).length;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final contacts = await _recipientStore.loadRecipients();
    final reminders = await _reminderStore.loadReminders();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = contacts.where((contact) => contact.consented).toList();
      _reminders = reminders;
      _isLoading = false;
    });
  }

  Future<void> _addReminder() async {
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
    DateTime scheduledAt = DateTime.now().add(const Duration(minutes: 5));
    final messageController = TextEditingController(
      text: 'Appointment reminder from Text Helper.',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: scheduledAt,
                firstDate: DateTime.now(),
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
              });
            }

            return SafeArea(
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
                    const Text(
                      'New appointment reminder',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<NzSmsRecipient>(
                      initialValue: selectedContact,
                      decoration: InputDecoration(
                        labelText: 'Contact',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _contacts
                          .map(
                            (contact) => DropdownMenuItem<NzSmsRecipient>(
                              value: contact,
                              child:
                                  Text('${contact.name} - ${contact.number}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setSheetState(() => selectedContact = value);
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
                    Text(
                      'Scheduled: ${_formatDateTime(scheduledAt)}',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Reminder message',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(CupertinoIcons.check_mark),
                      label: const Text('Save reminder'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactId: selectedContact.id,
      contactName: selectedContact.name,
      phoneNumber: selectedContact.number,
      appointmentTitle: 'Appointment',
      location: '',
      message: message,
      scheduledAt: scheduledAt,
      isSent: false,
      recurrenceRule: 'once',
      templateName: 'Custom',
    );

    await _reminderStore.addReminder(reminder);
    await _loadAll();
  }

  Future<void> _sendDueReminders() async {
    if (_isSending) {
      return;
    }

    final now = DateTime.now();

    final due = _reminders
        .where((reminder) =>
            !reminder.isSent && !reminder.scheduledAt.isAfter(now))
        .toList();

    if (due.isEmpty) {
      setState(() => _status = 'No due reminders.');
      return;
    }

    setState(() {
      _isSending = true;
      _status = 'Sending ${due.length} due reminder(s)...';
    });

    for (final reminder in due) {
      try {
        await _smsService.sendSms(
          phoneNumber: reminder.phoneNumber,
          message: reminder.message,
        );

        await _reminderStore.updateReminder(
          reminder.copyWith(
            isSent: true,
            sentAt: DateTime.now(),
          ),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() => _status = 'Send failed: $error');
        break;
      }
    }

    await _loadAll();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
      _status = 'Due reminders processed.';
    });
  }

  void _startScheduler() {
    _schedulerTimer?.cancel();

    setState(() {
      _schedulerRunning = true;
      _status = 'Scheduler running. App must stay open.';
    });

    _schedulerTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendDueReminders(),
    );
  }

  void _forceStop() {
    _schedulerTimer?.cancel();

    setState(() {
      _schedulerRunning = false;
      _isSending = false;
      _status = 'Scheduler force stopped.';
    });
  }

  Future<void> _deleteReminder(AppointmentReminder reminder) async {
    await _reminderStore.deleteReminder(reminder.id);
    await _loadAll();
  }

  Future<void> _clearSent() async {
    await _reminderStore.clearSent();
    await _loadAll();
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Appointment Reminders'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _addReminder,
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add reminder'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _HeroCard(
                  pendingCount: _pendingCount,
                  dueCount: _dueCount,
                  sentCount: _sentCount,
                  running: _schedulerRunning,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSending ? null : _sendDueReminders,
                  icon: const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(_isSending ? 'Sending...' : 'Send due now'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _schedulerRunning ? null : _startScheduler,
                        icon: const Icon(CupertinoIcons.play_fill),
                        label: const Text('Start scheduler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _schedulerRunning ? _forceStop : null,
                        icon: const Icon(CupertinoIcons.stop_fill),
                        label: const Text('Force stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearSent,
                  icon: const Icon(CupertinoIcons.trash),
                  label: const Text('Clear sent reminders'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scheduled reminders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_reminders.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No reminders yet. Tap Add reminder.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._reminders.map(
                    (reminder) => _ReminderCard(
                      reminder: reminder,
                      formatter: _formatDateTime,
                      onDelete: () => _deleteReminder(reminder),
                    ),
                  ),
                const SizedBox(height: 12),
                const _SafetyNote(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.pendingCount,
    required this.dueCount,
    required this.sentCount,
    required this.running,
  });

  final int pendingCount;
  final int dueCount;
  final int sentCount;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: running ? const Color(0xFF0A84FF) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        'Appointment reminders\n$dueCount due - $pendingCount pending - $sentCount sent',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          height: 1.16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.formatter,
    required this.onDelete,
  });

  final AppointmentReminder reminder;
  final String Function(DateTime value) formatter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final due =
        !reminder.isSent && !reminder.scheduledAt.isAfter(DateTime.now());

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
      ),
      child: _SurfaceCard(
        borderColor: due ? const Color(0xFFF97316) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              reminder.isSent
                  ? CupertinoIcons.check_mark_circled_solid
                  : due
                      ? CupertinoIcons.bell_fill
                      : CupertinoIcons.clock_fill,
              color: reminder.isSent
                  ? const Color(0xFF16A34A)
                  : due
                      ? const Color(0xFFF97316)
                      : const Color(0xFF0A84FF),
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
                    formatter(reminder.scheduledAt),
                    style: const TextStyle(
                      color: Color(0xFF0A84FF),
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
              reminder.isSent
                  ? 'Sent'
                  : due
                      ? 'Due'
                      : 'Pending',
              style: TextStyle(
                color: reminder.isSent
                    ? const Color(0xFF16A34A)
                    : due
                        ? const Color(0xFFF97316)
                        : const Color(0xFF0A84FF),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'This scheduler sends due reminders only while the app is open. Use approved contacts only. For true background reminders, the next feature should use Android AlarmManager or WorkManager.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(22),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: child,
    );
  }
}
