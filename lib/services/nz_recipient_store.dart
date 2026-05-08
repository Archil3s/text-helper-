import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nz_sms_recipient.dart';

class NzRecipientStore {
  static const String _key = 'text_helper_nz_sms_recipients';

  static List<NzSmsRecipient>? _memoryCache;

  Future<List<NzSmsRecipient>> loadRecipients() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = seedRecipients;
        await saveRecipients(_memoryCache!);
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = seedRecipients;
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map((item) =>
              NzSmsRecipient.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.number.isNotEmpty)
          .toList();

      if (_memoryCache!.isEmpty) {
        _memoryCache = seedRecipients;
      }

      return _memoryCache!;
    } catch (_) {
      _memoryCache = seedRecipients;
      return _memoryCache!;
    }
  }

  Future<void> saveRecipients(List<NzSmsRecipient> recipients) async {
    _memoryCache = recipients;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(recipients.map((recipient) => recipient.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addRecipient(NzSmsRecipient recipient) async {
    final recipients = await loadRecipients();
    await saveRecipients([recipient, ...recipients]);
  }

  Future<void> updateRecipient(NzSmsRecipient updated) async {
    final recipients = await loadRecipients();
    await saveRecipients(
      recipients
          .map((recipient) => recipient.id == updated.id ? updated : recipient)
          .toList(),
    );
  }

  Future<void> deleteRecipient(String id) async {
    final recipients = await loadRecipients();
    await saveRecipients(
      recipients.where((recipient) => recipient.id != id).toList(),
    );
  }

  Future<void> resetDemoRecipients() async {
    await saveRecipients(seedRecipients);
  }

  List<NzSmsRecipient> get seedRecipients {
    return const [
      NzSmsRecipient(
        id: 'demo-1',
        name: 'My Test Number',
        number: '+64211234567',
        consented: true,
        note: 'Replace this with your own test number',
        isTestNumber: true,
      ),
    ];
  }
}
