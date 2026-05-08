import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NzWorkflowStorageService {
  static const String nzNumbersKey = 'text_helper_nz_numbers';
  static const String consentRecordsKey = 'text_helper_consent_records';
  static const String campaignDraftKey = 'text_helper_campaign_draft';
  static const String finalReviewKey = 'text_helper_final_review';
  static const String manualExportKey = 'text_helper_manual_export';

  Future<List<Map<String, dynamic>>> readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(key);

    if (rawValue == null || rawValue.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(rawValue);

    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> writeList(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(values));
  }

  Future<Map<String, dynamic>> readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(key);

    if (rawValue == null || rawValue.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(rawValue);

    if (decoded is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<void> seedDemoWorkflow() async {
    await writeList(nzNumbersKey, [
      {
        'original': '021 123 4567',
        'normalized': '+64211234567',
        'isValid': true,
      },
      {
        'original': '027 555 1234',
        'normalized': '+64275551234',
        'isValid': true,
      },
      {
        'original': '+64 22 123 4567',
        'normalized': '+64221234567',
        'isValid': true,
      },
    ]);

    await writeList(consentRecordsKey, [
      {
        'name': 'Alex Carter',
        'number': '+64211234567',
        'source': 'Manual opt-in',
        'hasConsent': true,
      },
      {
        'name': 'Morgan Lee',
        'number': '+64275551234',
        'source': 'Imported list',
        'hasConsent': false,
      },
      {
        'name': 'Taylor Brooks',
        'number': '+64221234567',
        'source': 'Manual opt-in',
        'hasConsent': true,
      },
    ]);

    await writeMap(campaignDraftKey, {
      'name': 'NZ Reminder Campaign',
      'message':
          'Hi, this is a reminder from Text Helper. Reply STOP to opt out.',
      'includeUnsubscribe': true,
      'requireConsent': true,
    });

    await writeMap(finalReviewKey, {
      'consentConfirmed': true,
      'messageReviewed': true,
      'unsubscribeIncluded': true,
      'auditTrailEnabled': true,
      'finalApproval': false,
    });

    await writeMap(manualExportKey, {
      'campaignName': 'NZ Reminder Campaign',
      'recipientCount': 3,
      'lastExportType': 'CSV',
      'sendingEnabled': false,
    });
  }

  Future<void> clearWorkflow() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(nzNumbersKey);
    await prefs.remove(consentRecordsKey);
    await prefs.remove(campaignDraftKey);
    await prefs.remove(finalReviewKey);
    await prefs.remove(manualExportKey);
  }
}
