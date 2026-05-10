enum WhatsAppRepeatRule {
  daily,
  weekly,
  monthly,
}

extension WhatsAppRepeatRuleLabel on WhatsAppRepeatRule {
  String get label {
    switch (this) {
      case WhatsAppRepeatRule.daily:
        return 'Daily';
      case WhatsAppRepeatRule.weekly:
        return 'Weekly';
      case WhatsAppRepeatRule.monthly:
        return 'Monthly';
    }
  }

  String get storageValue {
    switch (this) {
      case WhatsAppRepeatRule.daily:
        return 'daily';
      case WhatsAppRepeatRule.weekly:
        return 'weekly';
      case WhatsAppRepeatRule.monthly:
        return 'monthly';
    }
  }

  static WhatsAppRepeatRule fromStorageValue(String value) {
    switch (value) {
      case 'weekly':
        return WhatsAppRepeatRule.weekly;
      case 'monthly':
        return WhatsAppRepeatRule.monthly;
      case 'daily':
      default:
        return WhatsAppRepeatRule.daily;
    }
  }
}

class WhatsAppRecurringHandoff {
  const WhatsAppRecurringHandoff({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.message,
    required this.repeatRule,
    required this.nextDueAt,
    required this.createdAt,
    this.lastOpenedAt,
    this.enabled = true,
    this.openCount = 0,
  });

  final String id;
  final String contactId;
  final String contactName;
  final String phoneNumber;
  final String message;
  final WhatsAppRepeatRule repeatRule;
  final DateTime nextDueAt;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final bool enabled;
  final int openCount;

  bool get isDue {
    return enabled && !nextDueAt.isAfter(DateTime.now());
  }

  DateTime get nextOccurrence {
    switch (repeatRule) {
      case WhatsAppRepeatRule.daily:
        return nextDueAt.add(const Duration(days: 1));
      case WhatsAppRepeatRule.weekly:
        return nextDueAt.add(const Duration(days: 7));
      case WhatsAppRepeatRule.monthly:
        return DateTime(
          nextDueAt.year,
          nextDueAt.month + 1,
          nextDueAt.day,
          nextDueAt.hour,
          nextDueAt.minute,
        );
    }
  }

  WhatsAppRecurringHandoff copyWith({
    String? id,
    String? contactId,
    String? contactName,
    String? phoneNumber,
    String? message,
    WhatsAppRepeatRule? repeatRule,
    DateTime? nextDueAt,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    bool? enabled,
    int? openCount,
  }) {
    return WhatsAppRecurringHandoff(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      message: message ?? this.message,
      repeatRule: repeatRule ?? this.repeatRule,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      enabled: enabled ?? this.enabled,
      openCount: openCount ?? this.openCount,
    );
  }

  factory WhatsAppRecurringHandoff.fromJson(Map<String, dynamic> json) {
    return WhatsAppRecurringHandoff(
      id: json['id'] as String? ?? '',
      contactId: json['contactId'] as String? ?? '',
      contactName: json['contactName'] as String? ?? 'Contact',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      message: json['message'] as String? ?? '',
      repeatRule: WhatsAppRepeatRuleLabel.fromStorageValue(
        json['repeatRule'] as String? ?? 'daily',
      ),
      nextDueAt: DateTime.tryParse(json['nextDueAt'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? ''),
      enabled: json['enabled'] as bool? ?? true,
      openCount: json['openCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'message': message,
      'repeatRule': repeatRule.storageValue,
      'nextDueAt': nextDueAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'enabled': enabled,
      'openCount': openCount,
    };
  }
}
