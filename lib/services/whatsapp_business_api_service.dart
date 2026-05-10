import 'dart:convert';
import 'dart:io';

class WhatsAppBusinessApiResult {
  const WhatsAppBusinessApiResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    this.providerMessageId,
    this.rawBody,
  });

  final bool ok;
  final int statusCode;
  final String message;
  final String? providerMessageId;
  final String? rawBody;
}

class WhatsAppBusinessApiService {
  Future<WhatsAppBusinessApiResult> sendTemplate({
    required String backendUrl,
    required String to,
    required String templateName,
    required String languageCode,
    required List<String> bodyParameters,
  }) async {
    final baseUrl = backendUrl.trim().replaceAll(RegExp(r'/+$'), '');

    if (baseUrl.isEmpty) {
      return const WhatsAppBusinessApiResult(
        ok: false,
        statusCode: 0,
        message: 'Backend URL is required.',
      );
    }

    final uri = Uri.parse('$baseUrl/whatsapp/send-template');
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(
          <String, Object?>{
            'to': to,
            'templateName': templateName,
            'languageCode': languageCode,
            'bodyParameters': bodyParameters,
          },
        ),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      final decoded = _tryDecode(body);
      final providerMessageId = decoded?['providerMessageId'] as String?;

      return WhatsAppBusinessApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        message: decoded?['message'] as String? ??
            decoded?['error'] as String? ??
            body,
        providerMessageId: providerMessageId,
        rawBody: body,
      );
    } catch (error) {
      return WhatsAppBusinessApiResult(
        ok: false,
        statusCode: 0,
        message: error.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<WhatsAppBusinessApiResult> healthCheck({
    required String backendUrl,
  }) async {
    final baseUrl = backendUrl.trim().replaceAll(RegExp(r'/+$'), '');

    if (baseUrl.isEmpty) {
      return const WhatsAppBusinessApiResult(
        ok: false,
        statusCode: 0,
        message: 'Backend URL is required.',
      );
    }

    final uri = Uri.parse('$baseUrl/health');
    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = _tryDecode(body);

      return WhatsAppBusinessApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        message: decoded?['message'] as String? ?? body,
        rawBody: body,
      );
    } catch (error) {
      return WhatsAppBusinessApiResult(
        ok: false,
        statusCode: 0,
        message: error.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }
}
