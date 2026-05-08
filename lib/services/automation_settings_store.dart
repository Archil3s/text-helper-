import 'package:shared_preferences/shared_preferences.dart';

class AutomationSettingsStore {
  static const String _testModeKey = 'text_helper_test_mode_enabled';

  static bool? _testModeCache;

  Future<bool> loadTestMode() async {
    if (_testModeCache != null) {
      return _testModeCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _testModeCache = prefs.getBool(_testModeKey) ?? true;
      return _testModeCache!;
    } catch (_) {
      _testModeCache = true;
      return true;
    }
  }

  Future<void> saveTestMode(bool value) async {
    _testModeCache = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_testModeKey, value);
    } catch (_) {}
  }
}
