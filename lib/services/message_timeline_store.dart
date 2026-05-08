import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/message_timeline_event.dart';

class MessageTimelineStore {
  static const String _key = 'text_helper_message_timeline_events';

  static List<MessageTimelineEvent>? _memoryCache;

  Future<List<MessageTimelineEvent>> loadEvents() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = <MessageTimelineEvent>[];
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = <MessageTimelineEvent>[];
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map(
            (item) =>
                MessageTimelineEvent.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();

      _memoryCache!.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return _memoryCache!;
    } catch (_) {
      _memoryCache = <MessageTimelineEvent>[];
      return _memoryCache!;
    }
  }

  Future<void> saveEvents(List<MessageTimelineEvent> events) async {
    final sorted = [...events]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final capped = sorted.take(1000).toList();

    _memoryCache = capped;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(capped.map((event) => event.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addEvent(MessageTimelineEvent event) async {
    final events = await loadEvents();
    await saveEvents([event, ...events]);
  }

  Future<void> clearEvents() async {
    await saveEvents(<MessageTimelineEvent>[]);
  }
}
