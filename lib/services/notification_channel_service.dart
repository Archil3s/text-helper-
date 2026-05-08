import 'package:flutter/services.dart';

class NotificationChannelDiagnostics {
  const NotificationChannelDiagnostics({
    required this.apiLevel,
    required this.permissionGranted,
    required this.notificationsEnabled,
    required this.channelCreated,
    required this.channelEnabled,
    required this.channelImportance,
  });

  factory NotificationChannelDiagnostics.fromMap(Map<dynamic, dynamic> map) {
    return NotificationChannelDiagnostics(
      apiLevel: _intValue(map['apiLevel']),
      permissionGranted: _boolValue(map['permissionGranted']),
      notificationsEnabled: _boolValue(map['notificationsEnabled']),
      channelCreated: _boolValue(map['channelCreated']),
      channelEnabled: _boolValue(map['channelEnabled']),
      channelImportance: (map['channelImportance'] ?? 'unknown').toString(),
    );
  }

  factory NotificationChannelDiagnostics.unavailable() {
    return const NotificationChannelDiagnostics(
      apiLevel: 0,
      permissionGranted: false,
      notificationsEnabled: false,
      channelCreated: false,
      channelEnabled: false,
      channelImportance: 'unavailable',
    );
  }

  final int apiLevel;
  final bool permissionGranted;
  final bool notificationsEnabled;
  final bool channelCreated;
  final bool channelEnabled;
  final String channelImportance;

  bool get ready {
    return permissionGranted &&
        notificationsEnabled &&
        channelCreated &&
        channelEnabled;
  }

  static bool _boolValue(Object? value) {
    return value == true;
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }
}

class NotificationChannelService {
  static const MethodChannel _channel =
      MethodChannel('text_helper/notification_channel');

  Future<NotificationChannelDiagnostics> getDiagnostics() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getNotificationDiagnostics',
      );

      return NotificationChannelDiagnostics.fromMap(result ?? const {});
    } catch (_) {
      return NotificationChannelDiagnostics.unavailable();
    }
  }

  Future<NotificationChannelDiagnostics> createReminderChannel() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'createReminderNotificationChannel',
      );

      return NotificationChannelDiagnostics.fromMap(result ?? const {});
    } catch (_) {
      return NotificationChannelDiagnostics.unavailable();
    }
  }

  Future<bool> requestPostNotificationsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestPostNotificationsPermission',
      );

      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendTestReminderNotification() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'sendTestReminderNotification',
      );

      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> openReminderNotificationChannelSettings() async {
    try {
      await _channel.invokeMethod<void>(
        'openReminderNotificationChannelSettings',
      );
    } catch (_) {}
  }
}
