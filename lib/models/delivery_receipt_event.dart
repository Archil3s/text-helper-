class DeliveryReceiptEvent {
  const DeliveryReceiptEvent({
    required this.id,
    required this.reminderId,
    required this.phoneNumber,
    required this.message,
    required this.event,
    required this.status,
    required this.resultCode,
    required this.createdAt,
    this.errorMessage,
  });

  final String id;
  final String? reminderId;
  final String phoneNumber;
  final String message;
  final String event;
  final String status;
  final int resultCode;
  final DateTime createdAt;
  final String? errorMessage;

  bool get isDelivered => status == 'delivered';

  bool get isSentToAndroid => status == 'sent_to_android_sms';

  bool get isFailed => status.contains('failed') || status == 'send_failed';

  factory DeliveryReceiptEvent.fromJson(Map<String, dynamic> json) {
    return DeliveryReceiptEvent(
      id: json['id'] as String? ?? '',
      reminderId: json['reminderId'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      message: json['message'] as String? ?? '',
      event: json['event'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      resultCode: json['resultCode'] is int
          ? json['resultCode'] as int
          : int.tryParse('${json['resultCode']}') ?? 0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reminderId': reminderId,
      'phoneNumber': phoneNumber,
      'message': message,
      'event': event,
      'status': status,
      'resultCode': resultCode,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
