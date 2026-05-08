import 'package:flutter/services.dart';

class NativeSmsService {
  static const MethodChannel _channel = MethodChannel('text_helper/native_sms');

  Future<void> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    await _channel.invokeMethod<void>('sendSms', {
      'phoneNumber': phoneNumber,
      'message': message,
    });
  }
}
