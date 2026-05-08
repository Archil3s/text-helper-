import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_template.dart';

class SmsTemplateStore {
  static const String _key = 'text_helper_sms_templates';

  static List<SmsTemplate>? _memoryCache;

  Future<List<SmsTemplate>> loadTemplates() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = seedTemplates;
        await saveTemplates(_memoryCache!);
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = seedTemplates;
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map((item) => SmsTemplate.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (_memoryCache!.isEmpty) {
        _memoryCache = seedTemplates;
      }

      return _memoryCache!;
    } catch (_) {
      _memoryCache = seedTemplates;
      return _memoryCache!;
    }
  }

  Future<void> saveTemplates(List<SmsTemplate> templates) async {
    final sorted = [...templates]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _memoryCache = sorted;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(sorted.map((template) => template.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addTemplate(SmsTemplate template) async {
    final templates = await loadTemplates();
    await saveTemplates([template, ...templates]);
  }

  Future<void> updateTemplate(SmsTemplate updated) async {
    final templates = await loadTemplates();

    await saveTemplates(
      templates
          .map((template) => template.id == updated.id ? updated : template)
          .toList(),
    );
  }

  Future<void> deleteTemplate(String id) async {
    final templates = await loadTemplates();

    await saveTemplates(
      templates.where((template) => template.id != id).toList(),
    );
  }

  Future<void> resetTemplates() async {
    await saveTemplates(seedTemplates);
  }

  String applyPlaceholders(
    String body, {
    required String name,
    required String date,
    required String time,
    required String location,
    required String appointment,
  }) {
    return body
        .replaceAll('{name}', name)
        .replaceAll('{date}', date)
        .replaceAll('{time}', time)
        .replaceAll('{location}', location)
        .replaceAll('{appointment}', appointment);
  }

  List<SmsTemplate> get seedTemplates {
    final now = DateTime.now();

    return [
      SmsTemplate(
        id: 'appointment-reminder',
        name: 'Appointment reminder',
        category: 'Appointment',
        body:
            'Hi {name}, reminder for your {appointment} on {date} at {time}{location}.',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      SmsTemplate(
        id: 'confirmation-request',
        name: 'Confirmation request',
        category: 'Confirmation',
        body:
            'Hi {name}, please reply YES to confirm your {appointment} on {date} at {time}{location}.',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      SmsTemplate(
        id: 'one-hour-reminder',
        name: 'One-hour reminder',
        category: 'Appointment',
        body: 'Hi {name}, your {appointment} is coming up at {time}{location}.',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      SmsTemplate(
        id: 'follow-up',
        name: 'Follow up',
        category: 'Follow up',
        body:
            'Hi {name}, following up about your {appointment}. Let me know if you need anything else.',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      SmsTemplate(
        id: 'running-late',
        name: 'Running late',
        category: 'Update',
        body:
            'Hi {name}, I am running a little late for {appointment}. I will update you as soon as possible.',
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
    ];
  }
}
