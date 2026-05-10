import 'package:url_launcher/url_launcher.dart';

class WhatsAppHandoffService {
  Future<bool> launchComposer({
    required String phoneNumber,
    required String message,
  }) async {
    final number = normalizeWhatsAppNumber(phoneNumber);
    final draft = message.trim();

    if (number.isEmpty || draft.isEmpty) {
      return false;
    }

    final encodedMessage = Uri.encodeComponent(draft);

    final appUri = Uri.parse(
      'whatsapp://send?phone=$number&text=$encodedMessage',
    );

    final webUri = Uri.parse(
      'https://wa.me/$number?text=$encodedMessage',
    );

    if (await _tryLaunch(appUri)) {
      return true;
    }

    return _tryLaunch(webUri);
  }

  String normalizeWhatsAppNumber(String phoneNumber) {
    final trimmed = phoneNumber.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    var cleaned = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleaned.startsWith('+')) {
      return cleaned.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
    }

    cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('00') && cleaned.length > 2) {
      return cleaned.substring(2);
    }

    // NZ local mobile format, for example 0211234567 -> 64211234567.
    if (cleaned.startsWith('0') && cleaned.length > 1) {
      return '64${cleaned.substring(1)}';
    }

    return cleaned;
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
