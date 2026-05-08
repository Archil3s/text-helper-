import 'package:flutter/services.dart';

import '../models/appointment_reminder.dart';

class BackgroundAlarmService {
  static const MethodChannel _channel =
      MethodChannel('text_helper/background_alarm');

  Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {}
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  Future<int> syncQueuedTexts(List<AppointmentReminder> reminders) async {
    final alarms = reminders.map((reminder) {
      return {
        'alarmId': reminder.id,
        'reminderId': reminder.id,
        'contactId': reminder.contactId,
        'phoneNumber': reminder.phoneNumber,
        'appointmentTitle': reminder.appointmentTitle,
        'location': reminder.location,
        'message': reminder.message,
        'scheduledAtMillis': reminder.scheduledAt.millisecondsSinceEpoch,
        'recurrenceRule': reminder.recurrenceRule,
        'templateName': reminder.templateName,
        'notes': reminder.notes ?? '',
      };
    }).toList();

    final result = await _channel.invokeMethod<int>(
      'syncBackgroundAlarms',
      {'alarms': alarms},
    );

    return result ?? 0;
  }

  Future<void> cancelAllBackgroundAlarms() async {
    try {
      await _channel.invokeMethod<void>('cancelAllBackgroundAlarms');
    } catch (_) {}
  }
}
