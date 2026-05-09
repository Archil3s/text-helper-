import 'dart:convert';

import 'package:flutter/services.dart';

import 'appointment_reminder_store.dart';
import 'background_alarm_service.dart';
import 'send_log_store.dart';

class CrashDiagnosticsReport {
  const CrashDiagnosticsReport({
    required this.generatedAt,
    required this.nativeDiagnostics,
    required this.totalReminders,
    required this.unsentReminders,
    required this.sentReminders,
    required this.totalLogs,
    required this.sentLogs,
    required this.failedLogs,
    required this.blockedLogs,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
    required this.recentFailures,
    required this.notes,
  });

  final DateTime generatedAt;
  final Map<String, dynamic> nativeDiagnostics;
  final int totalReminders;
  final int unsentReminders;
  final int sentReminders;
  final int totalLogs;
  final int sentLogs;
  final int failedLogs;
  final int blockedLogs;
  final bool exactAlarmsAllowed;
  final bool batteryUnrestricted;
  final List<Map<String, dynamic>> recentFailures;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'nativeDiagnostics': nativeDiagnostics,
      'queue': {
        'totalReminders': totalReminders,
        'unsentReminders': unsentReminders,
        'sentReminders': sentReminders,
      },
      'sendLogs': {
        'totalLogs': totalLogs,
        'sentLogs': sentLogs,
        'failedLogs': failedLogs,
        'blockedLogs': blockedLogs,
      },
      'backgroundHealth': {
        'exactAlarmsAllowed': exactAlarmsAllowed,
        'batteryUnrestricted': batteryUnrestricted,
      },
      'recentFailures': recentFailures,
      'notes': notes,
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

class CrashDiagnosticsService {
  CrashDiagnosticsService({
    AppointmentReminderStore? reminderStore,
    SendLogStore? logStore,
    BackgroundAlarmService? alarmService,
  })  : _reminderStore = reminderStore ?? AppointmentReminderStore(),
        _logStore = logStore ?? SendLogStore(),
        _alarmService = alarmService ?? BackgroundAlarmService();

  static const MethodChannel _deviceChannel =
      MethodChannel('text_helper/device_diagnostics');

  final AppointmentReminderStore _reminderStore;
  final SendLogStore _logStore;
  final BackgroundAlarmService _alarmService;

  Future<CrashDiagnosticsReport> buildReport({String notes = ''}) async {
    final nativeDiagnostics = await _loadNativeDiagnostics();
    final reminders = await _reminderStore.loadReminders();
    final logs = await _logStore.loadLogs();
    final exactAlarmsAllowed = await _alarmService.canScheduleExactAlarms();
    final batteryUnrestricted =
        await _alarmService.isIgnoringBatteryOptimizations();

    final unsentReminders = reminders.where((item) => !item.isSent).length;
    final sentReminders = reminders.where((item) => item.isSent).length;
    final sentLogs = logs.where((item) => item.status == 'sent').length;
    final failedLogs = logs.where((item) => item.status == 'failed').length;
    final blockedLogs = logs.where((item) => item.status == 'blocked').length;

    final recentFailures = logs
        .where((item) => item.status == 'failed' || item.status == 'blocked')
        .take(10)
        .map(
          (item) => {
            'createdAt': item.createdAt.toIso8601String(),
            'status': item.status,
            'phoneNumber': item.phoneNumber,
            'errorMessage': item.errorMessage ?? '',
            'reminderId': item.reminderId ?? '',
          },
        )
        .toList();

    return CrashDiagnosticsReport(
      generatedAt: DateTime.now(),
      nativeDiagnostics: nativeDiagnostics,
      totalReminders: reminders.length,
      unsentReminders: unsentReminders,
      sentReminders: sentReminders,
      totalLogs: logs.length,
      sentLogs: sentLogs,
      failedLogs: failedLogs,
      blockedLogs: blockedLogs,
      exactAlarmsAllowed: exactAlarmsAllowed,
      batteryUnrestricted: batteryUnrestricted,
      recentFailures: recentFailures,
      notes: notes.trim(),
    );
  }

  Future<Map<String, dynamic>> _loadNativeDiagnostics() async {
    try {
      final result = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'getDeviceDiagnostics',
      );

      return Map<String, dynamic>.from(result ?? const <String, dynamic>{});
    } catch (error) {
      return {
        'error': error.toString(),
        'androidRelease': 'unknown',
        'apiLevel': 0,
        'manufacturer': 'unknown',
        'model': 'unknown',
        'batteryPercent': -1,
        'batteryCharging': false,
        'smsPermissionGranted': false,
        'notificationsPermissionGranted': false,
      };
    }
  }
}
