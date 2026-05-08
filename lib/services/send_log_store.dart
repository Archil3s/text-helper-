import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/send_log_entry.dart';

class SendLogStore {
  static const String _key = 'text_helper_send_log';

  static List<SendLogEntry>? _memoryCache;

  Future<List<SendLogEntry>> loadLogs() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = <SendLogEntry>[];
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = <SendLogEntry>[];
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map((item) => SendLogEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return _memoryCache!;
    } catch (_) {
      _memoryCache = <SendLogEntry>[];
      return _memoryCache!;
    }
  }

  Future<void> saveLogs(List<SendLogEntry> logs) async {
    final sorted = [...logs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _memoryCache = sorted.take(500).toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_memoryCache!.map((log) => log.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addLog(SendLogEntry log) async {
    final logs = await loadLogs();
    await saveLogs([log, ...logs]);
  }

  Future<void> clearLogs() async {
    _memoryCache = <SendLogEntry>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
