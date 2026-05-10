import 'package:flutter/services.dart';

class WhatsAppHandoffService {
  static const MethodChannel _channel = MethodChannel(
    'text_helper/whatsapp_handoff',
  );

  Future<bool> isWhatsAppInstalled() async {
    try {
      final installed = await _channel.invokeMethod<bool>(
        'isWhatsAppInstalled',
      );

      return installed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> launchComposer({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'launchWhatsAppHandoff',
        <String, Object?>{
          'phoneNumber': phoneNumber,
          'message': message,
        },
      );

      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
