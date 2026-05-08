import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/appointment_reminder.dart';
import '../models/nz_sms_recipient.dart';
import '../services/appointment_reminder_store.dart';
import '../services/nz_recipient_store.dart';

class VisualCalendarScreen extends StatefulWidget {
  const VisualCalendarScreen({super.key});

  @override
  State<VisualCalendarScreen> createState() => _VisualCalendarScreenState();
}

class _VisualCalendarScreenState extends State<VisualCalendarScreen> {
  final AppointmentReminderStore _reminderStore = AppointmentReminderStore();
  final NzRecipientStore _recipientStore = NzRecipientStore();

  List<AppointmentReminder> _reminders = <AppointmentReminder>[];
  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final reminders = await _reminderStore.loadReminders();
    final contacts = await _recipientStore.loadRecipients();

    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _contacts = contacts.where((item) => item.consented).toList();
      _isLoading = false;
    });
  }

  List<AppointmentReminder> _remindersForDay(DateTime day) {
    final items = _reminders.where((reminder) {
      return reminder.scheduledAt.year == day.year &&
          reminder.scheduledAt.month == day.month &&
          reminder.scheduledAt.day == day.day;
    }).toList();

    items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime value) {
    return _isSameDay(value, DateTime.now());
  }

  String _monthLabel(DateTime month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${names[month.month - 1]} ${month.year}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _repeatLabel(String value) {
    return switch (value) {
      'everyMinute' => 'Every minute',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      _ => 'Once',
    };
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

  Future<void> _addReminderForSelectedDay() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an approved contact first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    NzSmsRecipient contact = _contacts.first;
    var scheduledAt = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      DateTime.now().hour,
      DateTime.now().minute,
    ).add(const Duration(minutes: 10));

    var template = 'Appointment reminder';
    var repeat = 'once';

    final titleController = TextEditingController(text: 'Appointment');
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    final messageController = TextEditingController(
      text: _templateMessage(
        template: template,
        name: contact.name,
        title: 'Appointment',
        location: '',
        scheduledAt: scheduledAt,
      ),
    );

    void rebuildMessage() {
      messageController.text = _templateMessage(
        template: template,
        name: contact.name,
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
                      const Text(
                        'Add calendar reminder',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<NzSmsRecipient>(
                        initialValue: contact,
                        decoration: _fieldDecoration('Contact'),
                        items: _contacts
                            .map(
                              (item) => DropdownMenuItem<NzSmsRecipient>(
                                value: item,
                                child: Text('${item.name} â€¢ ${item.number}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            contact = value;
                            rebuildMessage();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: _fieldDecoration('Appointment type'),
                        onChanged: (_) => setSheetState(rebuildMessage),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: _fieldDecoration('Location'),
                        onChanged: (_) => setSheetState(rebuildMessage),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: template,
                        decoration: _fieldDecoration('Message template'),
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
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            template = value;
                            rebuildMessage();
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
                        value:
                            '${_formatDate(scheduledAt)} at ${_formatTime(scheduledAt)}',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: _fieldDecoration('Message'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: _fieldDecoration('Notes'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(CupertinoIcons.check_mark),
                        label: const Text('Save reminder'),
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

    final reminder = AppointmentReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactId: contact.id,
      contactName: contact.name,
      phoneNumber: contact.number,
      appointmentTitle: titleController.text.trim().isEmpty
          ? 'Appointment'
          : titleController.text.trim(),
      location: locationController.text.trim(),
      message: messageController.text.trim(),
      scheduledAt: scheduledAt,
      isSent: false,
      recurrenceRule: repeat,
      templateName: template,
      notes: notesController.text.trim(),
    );

    await _reminderStore.addReminder(reminder);
    await _loadAll();
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

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedReminders = _remindersForDay(_selectedDay);
    final pendingCount = _reminders.where((item) => !item.isSent).length;
    final sentCount = _reminders.where((item) => item.isSent).length;

    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;
    final cellCount = startOffset + daysInMonth;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Visual Calendar'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _addReminderForSelectedDay,
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminderForSelectedDay,
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Add reminder'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _CalendarHero(
                  totalCount: _reminders.length,
                  pendingCount: pendingCount,
                  sentCount: sentCount,
                ),
                const SizedBox(height: 20),
                _MonthHeader(
                  label: _monthLabel(_visibleMonth),
                  onPrevious: _previousMonth,
                  onNext: _nextMonth,
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _WeekdayLabel('Sun'),
                    _WeekdayLabel('Mon'),
                    _WeekdayLabel('Tue'),
                    _WeekdayLabel('Wed'),
                    _WeekdayLabel('Thu'),
                    _WeekdayLabel('Fri'),
                    _WeekdayLabel('Sat'),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  itemCount: cellCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    if (index < startOffset) {
                      return const SizedBox.shrink();
                    }

                    final dayNumber = index - startOffset + 1;
                    final day = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month,
                      dayNumber,
                    );

                    final reminders = _remindersForDay(day);
                    final selected = _isSameDay(day, _selectedDay);
                    final today = _isToday(day);
                    final due = reminders.any(
                      (item) =>
                          !item.isSent &&
                          !item.scheduledAt.isAfter(DateTime.now()),
                    );

                    return _CalendarDayCell(
                      dayNumber: dayNumber,
                      reminderCount: reminders.length,
                      isSelected: selected,
                      isToday: today,
                      hasDueReminder: due,
                      onTap: () => setState(() => _selectedDay = day),
                    );
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatDate(_selectedDay)} reminders',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${selectedReminders.length}',
                        style: const TextStyle(
                          color: Color(0xFF0A84FF),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedReminders.isEmpty)
                  _EmptyDayCard(onAdd: _addReminderForSelectedDay)
                else
                  ...selectedReminders.map(
                    (reminder) => _ReminderAgendaCard(
                      reminder: reminder,
                      time: _formatTime(reminder.scheduledAt),
                      repeat: _repeatLabel(reminder.recurrenceRule),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CalendarHero extends StatelessWidget {
  const _CalendarHero({
    required this.totalCount,
    required this.pendingCount,
    required this.sentCount,
  });

  final int totalCount;
  final int pendingCount;
  final int sentCount;

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
            color: const Color(0xFF111827).withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.calendar,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Visual scheduler',
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
            'Plan reminder texts by day, contact, template, and time.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$totalCount', label: 'total'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$pendingCount', label: 'pending'),
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          _RoundIconButton(
            icon: CupertinoIcons.chevron_left,
            onTap: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          _RoundIconButton(
            icon: CupertinoIcons.chevron_right,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.dayNumber,
    required this.reminderCount,
    required this.isSelected,
    required this.isToday,
    required this.hasDueReminder,
    required this.onTap,
  });

  final int dayNumber;
  final int reminderCount;
  final bool isSelected;
  final bool isToday;
  final bool hasDueReminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? const Color(0xFF0A84FF)
        : hasDueReminder
            ? const Color(0xFFFFF7ED)
            : Colors.white;

    final borderColor = isSelected
        ? const Color(0xFF0A84FF)
        : isToday
            ? const Color(0xFF0A84FF)
            : reminderCount > 0
                ? const Color(0xFFF97316)
                : Colors.transparent;

    final textColor = isSelected ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.26),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            if (reminderCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : hasDueReminder
                          ? const Color(0xFFF97316)
                          : const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$reminderCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF0A84FF)
                      : CupertinoColors.systemGrey4,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderAgendaCard extends StatelessWidget {
  const _ReminderAgendaCard({
    required this.reminder,
    required this.time,
    required this.repeat,
  });

  final AppointmentReminder reminder;
  final String time;
  final String repeat;

  @override
  Widget build(BuildContext context) {
    final due =
        !reminder.isSent && !reminder.scheduledAt.isAfter(DateTime.now());

    final color = reminder.isSent
        ? const Color(0xFF16A34A)
        : due
            ? const Color(0xFFF97316)
            : const Color(0xFF0A84FF);

    return _SurfaceCard(
      borderColor: due ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  reminder.isSent
                      ? CupertinoIcons.check_mark_circled_solid
                      : due
                          ? CupertinoIcons.bell_fill
                          : CupertinoIcons.clock_fill,
                  color: color,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
                  reminder.appointmentTitle,
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (reminder.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.location,
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  reminder.message,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: reminder.isSent
                          ? 'Sent'
                          : due
                              ? 'Due'
                              : 'Pending',
                      color: color,
                    ),
                    _StatusChip(
                      label: repeat,
                      color: const Color(0xFF111827),
                    ),
                    _StatusChip(
                      label: reminder.templateName,
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.calendar_badge_plus,
            color: Color(0xFF0A84FF),
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'No reminders on this day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add an appointment reminder for the selected date.',
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
            label: const Text('Add reminder'),
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

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CupertinoColors.secondaryLabel,
          fontSize: 12,
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
