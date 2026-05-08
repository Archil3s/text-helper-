import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_receipt_event.dart';

class DeliveryReceiptStore {
  static const String _key = 'text_helper_delivery_receipts';

  static List<DeliveryReceiptEvent>? _memoryCache;

  Future<List<DeliveryReceiptEvent>> loadReceipts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = <DeliveryReceiptEvent>[];
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = <DeliveryReceiptEvent>[];
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map(
            (item) =>
                DeliveryReceiptEvent.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return _memoryCache!;
    } catch (_) {
      _memoryCache = <DeliveryReceiptEvent>[];
      return _memoryCache!;
    }
  }

  Future<void> clearReceipts() async {
    _memoryCache = <DeliveryReceiptEvent>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, '[]');
    } catch (_) {}
  }
}
