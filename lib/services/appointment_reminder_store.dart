import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment_reminder.dart';

class AppointmentReminderStore {
  static const String _key = 'text_helper_appointment_reminders';

  static List<AppointmentReminder>? _memoryCache;

  Future<List<AppointmentReminder>> loadReminders() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = <AppointmentReminder>[];
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = <AppointmentReminder>[];
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map((item) =>
              AppointmentReminder.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      return _memoryCache!;
    } catch (_) {
      _memoryCache = <AppointmentReminder>[];
      return _memoryCache!;
    }
  }

  Future<void> saveReminders(List<AppointmentReminder> reminders) async {
    final sorted = [...reminders]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    _memoryCache = sorted;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(sorted.map((reminder) => reminder.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addReminder(AppointmentReminder reminder) async {
    final reminders = await loadReminders();
    await saveReminders([reminder, ...reminders]);
  }

  Future<void> updateReminder(AppointmentReminder updated) async {
    final reminders = await loadReminders();
    await saveReminders(
      reminders
          .map((reminder) => reminder.id == updated.id ? updated : reminder)
          .toList(),
    );
  }

  Future<void> deleteReminder(String id) async {
    final reminders = await loadReminders();
    await saveReminders(
      reminders.where((reminder) => reminder.id != id).toList(),
    );
  }

  Future<void> clearSent() async {
    final reminders = await loadReminders();
    await saveReminders(
        reminders.where((reminder) => !reminder.isSent).toList());
  }
}
