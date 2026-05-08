import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_validation_result.dart';
import '../services/schedule_validation_service.dart';

class ScheduleValidationScreen extends StatefulWidget {
  const ScheduleValidationScreen({super.key});

  @override
  State<ScheduleValidationScreen> createState() =>
      _ScheduleValidationScreenState();
}

class _ScheduleValidationScreenState extends State<ScheduleValidationScreen> {
  static const String _use24HourKey = 'text_helper_use_24_hour_time';

  final ScheduleValidationService _service = ScheduleValidationService();
  final TextEditingController _customIntervalController =
      TextEditingController(text: '2');

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _windowStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _windowEnd = const TimeOfDay(hour: 20, minute: 0);

  String _repeatRule = 'once';
  String _customUnit = 'days';

  bool _loading = true;
  bool _use24Hour = true;

  ScheduleValidationResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customIntervalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final use24Hour = prefs.getBool(_use24HourKey) ?? true;

    if (!mounted) {
      return;
    }

    setState(() {
      _use24Hour = use24Hour;
      _loading = false;
    });

    _validate();
  }

  Future<void> _saveHourPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_use24HourKey, value);

    if (!mounted) {
      return;
    }

    setState(() => _use24Hour = value);
    _validate();
  }

  RepeatConfig _config() {
    return RepeatConfig(
      rule: _repeatRule,
      customInterval: int.tryParse(_customIntervalController.text.trim()) ?? 0,
      customUnit: _customUnit,
      windowStartHour: _windowStart.hour,
      windowStartMinute: _windowStart.minute,
      windowEndHour: _windowEnd.hour,
      windowEndMinute: _windowEnd.minute,
    );
  }

  void _validate() {
    final result = _service.validate(
      firstRun: _selectedDateTime,
      repeat: _config(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _result = result);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });

    _validate();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: _use24Hour,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });

    _validate();
  }

  Future<void> _pickWindowStart() async {
    final picked = await _pickWindowTime(_windowStart);

    if (picked == null) {
      return;
    }

    setState(() => _windowStart = picked);
    _validate();
  }

  Future<void> _pickWindowEnd() async {
    final picked = await _pickWindowTime(_windowEnd);

    if (picked == null) {
      return;
    }

    setState(() => _windowEnd = picked);
    _validate();
  }

  Future<TimeOfDay?> _pickWindowTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: _use24Hour,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');

    if (_use24Hour) {
      return '$date ${hour.toString().padLeft(2, '0')}:$minute';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$date $displayHour:$minute $period';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    if (_use24Hour) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }

    final period = value.hour >= 12 ? 'PM' : 'AM';
    final displayHour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    return '$displayHour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  String _repeatLabel(String rule) {
    return switch (rule) {
      'once' => 'Once',
      'everyMinute' => 'Every minute',
      'hourly' => 'Hourly',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'custom' => 'Custom interval',
      _ => rule,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final valid = result?.isValid ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Schedule Builder'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _validate,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ScheduleHero(
                  valid: valid,
                  warningCount: result?.warnings.length ?? 0,
                  occurrenceCount: result?.nextOccurrences.length ?? 0,
                ),
                const SizedBox(height: 20),
                _SurfaceCard(
                  child: Text(
                    'Validate the final scheduled date/time before saving. Use this to preview recurring messages, custom intervals, sending windows, and 12-hour/24-hour display behavior.',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: SwitchListTile(
                    value: _use24Hour,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Use 24-hour time',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Turn off for 12-hour AM/PM display.',
                    ),
                    onChanged: _saveHourPreference,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'First send',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.calendar,
                    label: 'Pick date',
                    value: _formatDateTime(_selectedDateTime).split(' ').first,
                    onPressed: _pickDate,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.clock_fill,
                    label: 'Pick time',
                    value: _formatDateTime(_selectedDateTime)
                        .replaceFirst(
                          _formatDateTime(_selectedDateTime).split(' ').first,
                          '',
                        )
                        .trim(),
                    onPressed: _pickTime,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Repeat',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: DropdownButtonFormField<String>(
                    initialValue: _repeatRule,
                    decoration: _fieldDecoration('Repeat rule'),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Once')),
                      DropdownMenuItem(
                        value: 'everyMinute',
                        child: Text('Every minute / test'),
                      ),
                      DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom interval'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() => _repeatRule = value);
                      _validate();
                    },
                  ),
                ),
                if (_repeatRule == 'custom') ...[
                  _SurfaceCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customIntervalController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration('Interval'),
                            onChanged: (_) => _validate(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _customUnit,
                            decoration: _fieldDecoration('Unit'),
                            items: const [
                              DropdownMenuItem(
                                value: 'minutes',
                                child: Text('Minutes'),
                              ),
                              DropdownMenuItem(
                                value: 'hours',
                                child: Text('Hours'),
                              ),
                              DropdownMenuItem(
                                value: 'days',
                                child: Text('Days'),
                              ),
                              DropdownMenuItem(
                                value: 'weeks',
                                child: Text('Weeks'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() => _customUnit = value);
                              _validate();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Sending window',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  left: _ActionButton(
                    icon: CupertinoIcons.sunrise_fill,
                    label: 'Window start',
                    value: _formatTimeOfDay(_windowStart),
                    onPressed: _pickWindowStart,
                  ),
                  right: _ActionButton(
                    icon: CupertinoIcons.sunset_fill,
                    label: 'Window end',
                    value: _formatTimeOfDay(_windowEnd),
                    onPressed: _pickWindowEnd,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Validation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ValidationCard(result: result),
                const SizedBox(height: 20),
                const Text(
                  'Next 5 occurrences',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (result == null || result.nextOccurrences.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No future occurrences generated.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...result.nextOccurrences.asMap().entries.map(
                        (entry) => _OccurrenceCard(
                          index: entry.key + 1,
                          dateTime: _formatDateTime(entry.value),
                          repeatLabel: _repeatLabel(_repeatRule),
                        ),
                      ),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'If device time, timezone, or battery settings change, re-check scheduled reminders. Android manufacturer restrictions can still delay alarms after a valid schedule is saved.',
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
}

class _ScheduleHero extends StatelessWidget {
  const _ScheduleHero({
    required this.valid,
    required this.warningCount,
    required this.occurrenceCount,
  });

  final bool valid;
  final int warningCount;
  final int occurrenceCount;

  @override
  Widget build(BuildContext context) {
    final color = valid ? const Color(0xFF16A34A) : const Color(0xFFF97316);

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
            CupertinoIcons.calendar_badge_plus,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Schedule validation',
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
            valid
                ? 'Schedule looks usable. Check the occurrences before saving.'
                : 'Review warnings before saving recurring reminders.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: valid ? 'OK' : 'CHECK', label: 'status'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$warningCount', label: 'warnings'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$occurrenceCount', label: 'next runs'),
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

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.left,
    required this.right,
  });

  final _ActionButton left;
  final _ActionButton right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF0A84FF)),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.result});

  final ScheduleValidationResult? result;

  @override
  Widget build(BuildContext context) {
    final current = result;

    if (current == null) {
      return const _SurfaceCard(
        child: Text('Validation has not run yet.'),
      );
    }

    final color =
        current.isValid ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    return _SurfaceCard(
      borderColor: current.warnings.isEmpty ? null : color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                current.isValid
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.exclamationmark_triangle_fill,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  current.isValid
                      ? 'Schedule looks valid'
                      : 'Schedule needs review',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (current.warnings.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No warnings found.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...current.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: color,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.index,
    required this.dateTime,
    required this.repeatLabel,
  });

  final int index;
  final String dateTime;
  final String repeatLabel;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0A84FF).withValues(alpha: 0.12),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateTime,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  repeatLabel,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
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
