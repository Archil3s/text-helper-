import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecurringTextsScreen extends StatefulWidget {
  const RecurringTextsScreen({super.key});

  @override
  State<RecurringTextsScreen> createState() => _RecurringTextsScreenState();
}

class _RecurringTextJob {
  const _RecurringTextJob({
    required this.id,
    required this.phoneNumber,
    required this.message,
    required this.scheduledAt,
    required this.recurrenceRule,
    required this.enabled,
    required this.label,
  });

  final String id;
  final String phoneNumber;
  final String message;
  final DateTime scheduledAt;
  final String recurrenceRule;
  final bool enabled;
  final String label;

  _RecurringTextJob copyWith({
    String? id,
    String? phoneNumber,
    String? message,
    DateTime? scheduledAt,
    String? recurrenceRule,
    bool? enabled,
    String? label,
  }) {
    return _RecurringTextJob(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      message: message ?? this.message,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }

  factory _RecurringTextJob.fromJson(Map<String, dynamic> json) {
    final rawScheduledAt = json['scheduledAt'] as String? ?? '';

    return _RecurringTextJob(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      message: json['message'] as String? ?? '',
      scheduledAt: DateTime.tryParse(rawScheduledAt)?.toLocal() ??
          DateTime.now().add(const Duration(minutes: 5)),
      recurrenceRule: json['recurrenceRule'] as String? ?? 'weekly',
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? 'Recurring text',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'message': message,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'recurrenceRule': recurrenceRule,
      'enabled': enabled,
      'label': label,
    };
  }

  Map<String, Object?> toAlarmJson() {
    return {
      'alarmId': id,
      'reminderId': id,
      'contactId': '',
      'phoneNumber': phoneNumber,
      'appointmentTitle': label,
      'location': '',
      'message': message,
      'scheduledAtMillis': scheduledAt.millisecondsSinceEpoch,
      'recurrenceRule': recurrenceRule,
      'templateName': 'Recurring',
      'notes': 'Recurring text created in Text Helper',
    };
  }
}

class _RecurringTextsScreenState extends State<RecurringTextsScreen> {
  static const String _jobsKey = 'text_helper_recurring_text_jobs';
  static const String _legacyRemindersKey = 'text_helper_appointment_reminders';
  static const MethodChannel _alarmChannel =
      MethodChannel('text_helper/background_alarm');

  final TextEditingController _labelController = TextEditingController(
    text: 'Weekly check in',
  );
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController(
    text: 'Hi, this is your recurring reminder from Text Helper.',
  );

  List<_RecurringTextJob> _jobs = <_RecurringTextJob>[];
  bool _loading = true;
  bool _syncing = false;
  String _recurrenceRule = 'weekly';
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 5));
  String _status =
      'Create recurring SMS jobs. Text Helper will schedule them with Android alarms.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jobsKey);
    final jobs = <_RecurringTextJob>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          jobs.addAll(
            decoded.whereType<Map>().map(
                  (item) => _RecurringTextJob.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
        }
      } catch (_) {}
    }

    jobs.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _jobs = jobs;
      _loading = false;
    });

    await _syncAlarms();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_jobs.map((job) => job.toJson()).toList());
    await prefs.setString(_jobsKey, encoded);

    await prefs.setString(
      _legacyRemindersKey,
      jsonEncode(
        _jobs.map((job) {
          return {
            'id': job.id,
            'contactId': '',
            'phoneNumber': job.phoneNumber,
            'appointmentTitle': job.label,
            'location': '',
            'message': job.message,
            'scheduledAt': job.scheduledAt.toUtc().toIso8601String(),
            'isSent': false,
            'recurrenceRule': job.recurrenceRule,
            'templateName': 'Recurring',
            'sentAt': null,
            'notes': 'Recurring text created in Text Helper',
          };
        }).toList(),
      ),
    );
  }

  Future<void> _syncAlarms() async {
    if (_syncing) {
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      final alarms = _jobs
          .where((job) => job.enabled)
          .map((job) => job.toAlarmJson())
          .toList();

      final count = await _alarmChannel.invokeMethod<int>(
            'syncBackgroundAlarms',
            {'alarms': alarms},
          ) ??
          0;

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Synced $count recurring text alarm${count == 1 ? '' : 's'}.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Could not sync alarms: ${error.message ?? error.code}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _saveAndSync() async {
    await _save();
    await _syncAlarms();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  List<String> _parseUniquePhoneNumbers(String raw) {
    final uniqueNumbers = <String>[];
    final seenKeys = <String>{};

    final parts = raw
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);

    for (final part in parts) {
      final normalizedKey = part.replaceAll(RegExp(r'[^0-9+]'), '');

      if (normalizedKey.isEmpty || seenKeys.contains(normalizedKey)) {
        continue;
      }

      seenKeys.add(normalizedKey);
      uniqueNumbers.add(part);
    }

    return uniqueNumbers;
  }

  Future<void> _addJob() async {
    final label = _labelController.text.trim();
    final phoneNumbers = _parseUniquePhoneNumbers(_phoneController.text);
    final message = _messageController.text.trim();

    if (phoneNumbers.isEmpty || message.isEmpty) {
      _showSnack('Enter at least one phone number and a message.');
      return;
    }

    if (_scheduledAt.isBefore(DateTime.now())) {
      _showSnack('Choose a future date and time.');
      return;
    }

    final baseTime = DateTime.now().microsecondsSinceEpoch;
    final jobLabel = label.isEmpty ? 'Recurring text' : label;

    final newJobs = <_RecurringTextJob>[];

    for (var index = 0; index < phoneNumbers.length; index += 1) {
      final phoneNumber = phoneNumbers[index];

      newJobs.add(
        _RecurringTextJob(
          id: 'recurring-$baseTime-$index',
          phoneNumber: phoneNumber,
          message: message,
          scheduledAt: _scheduledAt,
          recurrenceRule: _recurrenceRule,
          enabled: true,
          label: phoneNumbers.length == 1
              ? jobLabel
              : '$jobLabel ${index + 1} of ${phoneNumbers.length}',
        ),
      );
    }

    setState(() {
      _jobs = [...newJobs, ..._jobs]
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _status =
          'Saved ${newJobs.length} recurring text job${newJobs.length == 1 ? '' : 's'}.';
    });

    await _saveAndSync();
  }

  Future<void> _toggleJob(_RecurringTextJob job) async {
    setState(() {
      _jobs = _jobs
          .map(
            (item) => item.id == job.id
                ? item.copyWith(enabled: !item.enabled)
                : item,
          )
          .toList();
      _status =
          job.enabled ? 'Recurring text disabled.' : 'Recurring text enabled.';
    });

    await _saveAndSync();
  }

  Future<void> _deleteJob(_RecurringTextJob job) async {
    setState(() {
      _jobs = _jobs.where((item) => item.id != job.id).toList();
      _status = 'Recurring text deleted.';
    });

    await _saveAndSync();
  }

  void _editJob(_RecurringTextJob job) {
    setState(() {
      _labelController.text = job.label;
      _phoneController.text = job.phoneNumber;
      _messageController.text = job.message;
      _scheduledAt = job.scheduledAt;
      _recurrenceRule = job.recurrenceRule;
      _status = 'Editing "${job.label}". Save to create a new recurring text.';
    });
  }

  Future<void> _requestSmsPermission() async {
    try {
      final granted = await _alarmChannel.invokeMethod<bool>(
            'requestSmsPermission',
          ) ??
          false;

      if (!mounted) {
        return;
      }

      setState(() {
        _status = granted
            ? 'SMS permission granted.'
            : 'SMS permission was not granted.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Could not request SMS permission: ${error.message ?? error.code}';
      });
    }
  }

  Future<void> _checkExactAlarms() async {
    try {
      final allowed = await _alarmChannel.invokeMethod<bool>(
            'canScheduleExactAlarms',
          ) ??
          true;

      if (!mounted) {
        return;
      }

      setState(() {
        _status = allowed
            ? 'Exact alarms are allowed.'
            : 'Exact alarms are not allowed. Open alarm settings.';
      });

      if (!allowed) {
        await _alarmChannel.invokeMethod<void>('openExactAlarmSettings');
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Could not check exact alarms: ${error.message ?? error.code}';
      });
    }
  }

  String _recurrenceLabel(String value) {
    switch (value) {
      case 'once':
        return 'Once';
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return value;
    }
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _jobs.where((job) => job.enabled).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Recurring Texts'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _syncing ? null : _syncAlarms,
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Sync alarms',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _HeroCard(),
                const SizedBox(height: 16),
                _StatusCard(status: _status),
                const SizedBox(height: 16),
                _SummaryRow(
                  totalCount: _jobs.length,
                  enabledCount: enabledCount,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Permissions'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      FilledButton.icon(
                        onPressed: _requestSmsPermission,
                        icon: const Icon(CupertinoIcons.chat_bubble_text_fill),
                        label: const Text('Request SMS Permission'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _checkExactAlarms,
                        icon: const Icon(CupertinoIcons.alarm_fill),
                        label: const Text('Check Exact Alarm Access'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Create recurring text'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          helperText: 'Example: Weekly check in',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          helperText: 'Use the full mobile number.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          helperText: 'This SMS will be sent automatically.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _recurrenceRule,
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'once',
                            child: Text('Once'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'daily',
                            child: Text('Daily'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _recurrenceRule = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(CupertinoIcons.calendar),
                              label: Text(
                                  _dateLabel(_scheduledAt).split(' ').first),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(CupertinoIcons.clock_fill),
                              label: Text(
                                  _dateLabel(_scheduledAt).split(' ').last),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addJob,
                        icon:
                            const Icon(CupertinoIcons.check_mark_circled_solid),
                        label: const Text('Save Scheduled Texts'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Saved recurring texts (${_jobs.length})'),
                const SizedBox(height: 12),
                if (_jobs.isEmpty)
                  const _EmptyCard()
                else
                  ..._jobs.map(
                    (job) => _JobCard(
                      job: job,
                      dateLabel: _dateLabel(job.scheduledAt),
                      recurrenceLabel: _recurrenceLabel(job.recurrenceRule),
                      onToggle: () => _toggleJob(job),
                      onEdit: () => _editJob(job),
                      onDelete: () => _deleteJob(job),
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
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.repeat,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Recurring Texts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Schedule one-time, daily, weekly, or monthly SMS messages for many unique people.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalCount,
    required this.enabledCount,
  });

  final int totalCount;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: totalCount.toString(),
            label: 'Recurring jobs',
            color: const Color(0xFF0A84FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: enabledCount.toString(),
            label: 'Enabled',
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
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
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.dateLabel,
    required this.recurrenceLabel,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final _RecurringTextJob job;
  final String dateLabel;
  final String recurrenceLabel;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                job.enabled
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.pause_circle_fill,
                color: job.enabled
                    ? const Color(0xFF16A34A)
                    : CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  job.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                job.enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: job.enabled
                      ? const Color(0xFF16A34A)
                      : CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.phoneNumber,
            style: const TextStyle(
              color: Color(0xFF0A84FF),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job.message,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Next: $dateLabel - Repeat: $recurrenceLabel',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  job.enabled
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                ),
                label: Text(job.enabled ? 'Disable' : 'Enable'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(CupertinoIcons.delete),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text(
        'No recurring texts saved yet.',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.35,
          fontWeight: FontWeight.w700,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.shield_fill, color: Color(0xFFF97316)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Recurring texts use SMS permission and local Android alarms. Keep messages consent-based and review exact alarm and battery settings for reliable delivery.',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
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
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}
