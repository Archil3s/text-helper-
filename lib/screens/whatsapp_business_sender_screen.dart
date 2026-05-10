import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WhatsAppBusinessSenderScreen extends StatefulWidget {
  const WhatsAppBusinessSenderScreen({super.key});

  @override
  State<WhatsAppBusinessSenderScreen> createState() =>
      _WhatsAppBusinessSenderScreenState();
}

class _WhatsAppBusinessSenderScreenState
    extends State<WhatsAppBusinessSenderScreen> {
  final TextEditingController _backendController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _paramsController = TextEditingController();

  final List<String> _logs = <String>[];

  Timer? _fiveSecondTimer;

  bool _busy = false;
  bool _fiveSecondRunning = false;
  int _secondsRemaining = 0;

  String _status =
      'Ready. This sends through your backend. WhatsApp does not open.';

  @override
  void initState() {
    super.initState();

    _backendController.text = 'http://192.168.1.229:8787';
    _phoneController.text = '64211234567';
    _templateController.text = 'hello_world';
    _languageController.text = 'en_US';
    _paramsController.text = '';
  }

  @override
  void dispose() {
    _fiveSecondTimer?.cancel();
    _backendController.dispose();
    _phoneController.dispose();
    _templateController.dispose();
    _languageController.dispose();
    _paramsController.dispose();
    super.dispose();
  }

  String get _baseUrl {
    return _backendController.text.trim().replaceAll(RegExp(r'/+$'), '');
  }

  List<String> get _parameters {
    return _paramsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _testBackend() async {
    if (_baseUrl.isEmpty) {
      _showSnack('Backend URL is required.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Testing backend...';
    });

    final result = await _getJson('$_baseUrl/health');

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _status = result.ok
          ? 'Backend connected: ${result.message}'
          : 'Backend failed: ${result.message}';
      _log(_status);
    });
  }

  Future<void> _sendNow() async {
    if (_baseUrl.isEmpty) {
      _showSnack('Backend URL is required.');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showSnack('Recipient phone is required.');
      return;
    }

    if (_templateController.text.trim().isEmpty) {
      _showSnack('Template name is required.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Sending through backend...';
    });

    final result = await _postJson(
      '$_baseUrl/whatsapp/send-template',
      <String, Object?>{
        'to': _phoneController.text.trim(),
        'templateName': _templateController.text.trim(),
        'languageCode': _languageController.text.trim(),
        'bodyParameters': _parameters,
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _status = result.ok
          ? 'Send request worked: ${result.message}'
          : 'Send failed: ${result.message}';
      _log(_status);
    });
  }

  void _startFiveSecondTest() {
    if (_fiveSecondRunning) {
      return;
    }

    _fiveSecondTimer?.cancel();

    setState(() {
      _fiveSecondRunning = true;
      _secondsRemaining = 5;
      _status = '5 second test started. Text Helper stays open.';
      _log(_status);
    });

    _fiveSecondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();

        setState(() {
          _fiveSecondRunning = false;
          _secondsRemaining = 0;
        });

        _sendNow();
        return;
      }

      setState(() {
        _secondsRemaining -= 1;
        _status = 'Sending through backend in $_secondsRemaining seconds...';
      });
    });
  }

  void _cancelFiveSecondTest() {
    _fiveSecondTimer?.cancel();

    setState(() {
      _fiveSecondRunning = false;
      _secondsRemaining = 0;
      _status = '5 second test cancelled.';
      _log(_status);
    });
  }

  Future<_ApiResult> _getJson(String url) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeMap(body);

      return _ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        message: decoded?['message']?.toString() ?? body,
      );
    } catch (error) {
      return _ApiResult(ok: false, message: error.toString());
    } finally {
      client.close(force: true);
    }
  }

  Future<_ApiResult> _postJson(String url, Map<String, Object?> payload) async {
    final client = HttpClient();

    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeMap(body);

      return _ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        message: decoded?['message']?.toString() ??
            decoded?['error']?.toString() ??
            body,
      );
    } catch (error) {
      return _ApiResult(ok: false, message: error.toString());
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  void _log(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '$time  $message');

    if (_logs.length > 25) {
      _logs.removeRange(25, _logs.length);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('WhatsApp Business Sender'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          _StatusCard(status: _status),
          const SizedBox(height: 16),
          const _PolicyCard(),
          const SizedBox(height: 20),
          const _SectionTitle('Backend'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              children: [
                TextField(
                  controller: _backendController,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    helperText:
                        'Your current PC Wi-Fi URL is http://192.168.1.229:8787',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _testBackend,
                  icon: const Icon(CupertinoIcons.link),
                  label: const Text('Test Backend Connection'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('WhatsApp template'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Recipient phone',
                    helperText:
                        'International format without +, for example 64211234567.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _templateController,
                  decoration: const InputDecoration(
                    labelText: 'Template name',
                    helperText:
                        'Use an approved WhatsApp Business template. Dry-run works without credentials.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _languageController,
                  decoration: const InputDecoration(
                    labelText: 'Language code',
                    helperText: 'Example: en_US.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paramsController,
                  decoration: const InputDecoration(
                    labelText: 'Template parameters',
                    helperText:
                        'Comma separated. Leave blank for no variables.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _sendNow,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.paperplane_fill),
                  label: Text(_busy ? 'Sending...' : 'Send Through Backend'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('5 second test'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fiveSecondRunning
                      ? 'Sending through backend in $_secondsRemaining seconds...'
                      : 'This keeps Text Helper open, waits 5 seconds, then calls the backend. WhatsApp does not open.',
                  style: const TextStyle(
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _fiveSecondRunning || _busy
                            ? null
                            : _startFiveSecondTest,
                        icon: const Icon(CupertinoIcons.timer),
                        label: const Text('Start 5 Sec Test'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _fiveSecondRunning ? _cancelFiveSecondTest : null,
                        icon: const Icon(CupertinoIcons.xmark_circle),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Activity'),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: _logs.isEmpty
                ? const Text(
                    'No activity yet.',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _logs
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              log,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApiResult {
  const _ApiResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.cloud_upload_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'WhatsApp Business Sender',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send through your backend. Normal WhatsApp does not open.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_shield_fill,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dry-run mode proves the phone can reach your backend. Real WhatsApp sending needs Meta WhatsApp Business credentials in backend\\whatsapp\\.env.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
