import '../models/schedule_validation_result.dart';

class ScheduleValidationService {
  ScheduleValidationResult validate({
    required DateTime firstRun,
    required RepeatConfig repeat,
  }) {
    final warnings = <String>[];
    final now = DateTime.now();

    if (firstRun.isBefore(now)) {
      warnings.add('Selected date/time is in the past.');
    }

    if (!_isInsideWindow(firstRun, repeat)) {
      warnings.add('Selected time is outside the configured sending window.');
    }

    if (repeat.rule == 'custom' && repeat.customInterval <= 0) {
      warnings.add('Custom interval must be greater than zero.');
    }

    if (repeat.rule == 'everyMinute') {
      warnings.add('Every-minute sending is for testing only. Use carefully.');
    }

    if (repeat.rule == 'monthly' && firstRun.day > 28) {
      warnings.add(
        'Monthly repeats after the 28th can shift because months have different lengths.',
      );
    }

    if (repeat.windowStartHour == repeat.windowEndHour &&
        repeat.windowStartMinute == repeat.windowEndMinute) {
      warnings.add('Sending window start and end are the same.');
    }

    final occurrences = nextOccurrences(
      firstRun: firstRun,
      repeat: repeat,
      count: 5,
    );

    if (occurrences.isEmpty) {
      warnings.add('No future occurrences could be generated.');
    }

    return ScheduleValidationResult(
      isValid: warnings.every((warning) =>
          !warning.contains('past') && !warning.contains('greater than zero')),
      warnings: warnings,
      nextOccurrences: occurrences,
    );
  }

  List<DateTime> nextOccurrences({
    required DateTime firstRun,
    required RepeatConfig repeat,
    required int count,
  }) {
    final occurrences = <DateTime>[];

    var current = firstRun;
    var safety = 0;

    while (occurrences.length < count && safety < 250) {
      safety += 1;

      if (current.isAfter(DateTime.now()) && _isInsideWindow(current, repeat)) {
        occurrences.add(current);
      }

      if (repeat.rule == 'once') {
        break;
      }

      current = _next(current, repeat);
    }

    return occurrences;
  }

  DateTime _next(DateTime current, RepeatConfig repeat) {
    switch (repeat.rule) {
      case 'everyMinute':
        return current.add(const Duration(minutes: 1));
      case 'hourly':
        return current.add(const Duration(hours: 1));
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return _addMonth(current);
      case 'custom':
        return _nextCustom(current, repeat);
      default:
        return current.add(const Duration(days: 1));
    }
  }

  DateTime _nextCustom(DateTime current, RepeatConfig repeat) {
    final interval = repeat.customInterval <= 0 ? 1 : repeat.customInterval;

    switch (repeat.customUnit) {
      case 'minutes':
        return current.add(Duration(minutes: interval));
      case 'hours':
        return current.add(Duration(hours: interval));
      case 'weeks':
        return current.add(Duration(days: interval * 7));
      case 'days':
      default:
        return current.add(Duration(days: interval));
    }
  }

  DateTime _addMonth(DateTime current) {
    final targetMonth = current.month == 12 ? 1 : current.month + 1;
    final targetYear = current.month == 12 ? current.year + 1 : current.year;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final safeDay = current.day > lastDay ? lastDay : current.day;

    return DateTime(
      targetYear,
      targetMonth,
      safeDay,
      current.hour,
      current.minute,
      current.second,
    );
  }

  bool _isInsideWindow(DateTime value, RepeatConfig repeat) {
    final minuteOfDay = value.hour * 60 + value.minute;
    final start = repeat.windowStartHour * 60 + repeat.windowStartMinute;
    final end = repeat.windowEndHour * 60 + repeat.windowEndMinute;

    if (start == end) {
      return false;
    }

    if (start < end) {
      return minuteOfDay >= start && minuteOfDay <= end;
    }

    return minuteOfDay >= start || minuteOfDay <= end;
  }
}
