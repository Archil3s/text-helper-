import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_group.dart';

class ContactGroupStore {
  static const String _key = 'text_helper_contact_groups';

  static List<ContactGroup>? _memoryCache;

  Future<List<ContactGroup>> loadGroups() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(_key);

      if (rawValue == null || rawValue.isEmpty) {
        _memoryCache = seedGroups;
        await saveGroups(_memoryCache!);
        return _memoryCache!;
      }

      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        _memoryCache = seedGroups;
        return _memoryCache!;
      }

      _memoryCache = decoded
          .whereType<Map>()
          .map((item) => ContactGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      return _memoryCache!;
    } catch (_) {
      _memoryCache = seedGroups;
      return _memoryCache!;
    }
  }

  Future<void> saveGroups(List<ContactGroup> groups) async {
    _memoryCache = groups;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(groups.map((group) => group.toJson()).toList()),
      );
    } catch (_) {}
  }

  List<ContactGroup> get seedGroups {
    return const [
      ContactGroup(id: 'test', name: 'Test Numbers', contactIds: []),
      ContactGroup(id: 'clients', name: 'Clients', contactIds: []),
      ContactGroup(id: 'appointments', name: 'Appointments', contactIds: []),
      ContactGroup(
        id: 'do-not-send',
        name: 'Do Not Send',
        contactIds: [],
        isBlockedGroup: true,
      ),
    ];
  }
}
