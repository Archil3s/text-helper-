import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/whatsapp_recurring_handoff.dart';

class WhatsAppRecurringHandoffStore {
  static const String _key = 'text_helper_whatsapp_recurring_handoffs';

  static List<WhatsAppRecurringHandoff>? _memoryCache;

  Future<List<WhatsAppRecurringHandoff>> loadItems() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = <WhatsAppRecurringHandoff>[];
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = <WhatsAppRecurringHandoff>[];
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map(
            (item) => WhatsAppRecurringHandoff.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.phoneNumber.isNotEmpty)
          .toList()
        ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

      return _memoryCache!;
    } catch (_) {
      _memoryCache = <WhatsAppRecurringHandoff>[];
      return _memoryCache!;
    }
  }

  Future<void> saveItems(List<WhatsAppRecurringHandoff> items) async {
    final sorted = [...items]
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

    _memoryCache = sorted;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(sorted.map((item) => item.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addItem(WhatsAppRecurringHandoff item) async {
    final items = await loadItems();
    await saveItems([item, ...items]);
  }

  Future<void> updateItem(WhatsAppRecurringHandoff updated) async {
    final items = await loadItems();
    await saveItems(
      items.map((item) => item.id == updated.id ? updated : item).toList(),
    );
  }

  Future<void> deleteItem(String id) async {
    final items = await loadItems();
    await saveItems(items.where((item) => item.id != id).toList());
  }

  Future<void> clearItems() async {
    _memoryCache = <WhatsAppRecurringHandoff>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
