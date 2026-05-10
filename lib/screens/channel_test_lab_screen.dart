import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nz_sms_recipient.dart';
import '../models/send_log_entry.dart';
import '../services/message_timeline_service.dart';
import '../services/nz_recipient_store.dart';
import '../services/send_log_store.dart';
import '../services/whatsapp_handoff_service.dart';
import 'direct_sms_screen.dart';
import 'send_history_screen.dart';
import 'send_queue_screen.dart';
import 'whatsapp_handoff_screen.dart';

class ChannelTestLabScreen extends StatefulWidget {
  const ChannelTestLabScreen({super.key});

  @override
  State<ChannelTestLabScreen> createState() => _ChannelTestLabScreenState();
}

class _ChannelTestLabScreenState extends State<ChannelTestLabScreen> {
  final NzRecipientStore _recipientStore = NzRecipientStore();
  final WhatsAppHandoffService _whatsAppService = WhatsAppHandoffService();
  final SendLogStore _sendLogStore = SendLogStore();
  final MessageTimelineService _timelineService = MessageTimelineService();

  final TextEditingController _testMessageController = TextEditingController();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedContact;

  Timer? _timer;

  bool _loading = true;
  bool _whatsAppInstalled = false;
  bool _countingDown = false;

  int _secondsRemaining = 0;

  String _status =
      'Ready. Use this screen to test SMS, RCS policy, WhatsApp handoff, and force-stop behaviour.';

  @override
  void initState() {
    super.initState();
    _testMessageController.text =
        '5 second WhatsApp test from Text Helper. Press Send manually if this looks correct.';
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _testMessageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await _recipientStore.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();
    final installed = await _whatsAppService.isWhatsAppInstalled();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approved;
      _selectedContact = approved.isEmpty ? null : approved.first;
      _whatsAppInstalled = installed;
      _loading = false;
    });
  }

  Future<void> _startFiveSecondWhatsAppTest() async {
    final contact = _selectedContact;

    if (contact == null) {
      _showSnack('Add or select an approved contact first.');
      return;
    }

    if (!_whatsAppInstalled) {
      _showSnack('WhatsApp was not detected on this phone.');
      return;
    }

    final message = _testMessageController.text.trim();

    if (message.isEmpty) {
      _showSnack('Write a test message first.');
      return;
    }

    _timer?.cancel();

    setState(() {
      _countingDown = true;
      _secondsRemaining = 5;
      _status = '5 second WhatsApp test started. Keep the app open.';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();

        setState(() {
          _countingDown = false;
          _secondsRemaining = 0;
          _status = 'Opening WhatsApp draft...';
        });

        await _openWhatsAppDraft(contact: contact, message: message);
        return;
      }

      setState(() {
        _secondsRemaining -= 1;
        _status = 'Opening WhatsApp draft in $_secondsRemaining seconds...';
      });
    });
  }

  void _cancelFiveSecondTest() {
    _timer?.cancel();

    setState(() {
      _countingDown = false;
      _secondsRemaining = 0;
      _status = '5 second test cancelled.';
    });
  }

  Future<void> _openWhatsAppDraft({
    required NzSmsRecipient contact,
    required String message,
  }) async {
    final id = 'channel-lab-whatsapp-${DateTime.now().microsecondsSinceEpoch}';

    await _recordLog(
      id: id,
      phoneNumber: contact.number,
      message: message,
      status: 'whatsapp_5_second_test_opening',
      detail:
          '5 second WhatsApp test started. User must press Send manually in WhatsApp.',
    );

    final opened = await _whatsAppService.launchComposer(
      phoneNumber: contact.number,
      message: message,
    );

    await _recordLog(
      id: id,
      phoneNumber: contact.number,
      message: message,
      status: opened
          ? 'whatsapp_5_second_test_opened'
          : 'whatsapp_5_second_test_failed',
      detail: opened
          ? 'WhatsApp draft opened after 5 seconds. User must press Send manually.'
          : 'Could not open WhatsApp draft after 5 seconds.',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _status = opened
          ? 'WhatsApp opened. Press Send manually inside WhatsApp.'
          : 'Could not open WhatsApp draft.';
    });
  }

  Future<void> _recordLog({
    required String id,
    required String phoneNumber,
    required String message,
    required String status,
    required String detail,
  }) async {
    final log = SendLogEntry(
      id: id,
      phoneNumber: phoneNumber,
      message: message,
      createdAt: DateTime.now(),
      status: status,
      errorMessage: detail,
      reminderId: id,
    );

    await _sendLogStore.addLog(log);
    await _timelineService.logFromSendLog(log);
  }

  Future<void> _copyForceStopCommand() async {
    const command = 'adb shell am force-stop com.example.text_helper';

    await Clipboard.setData(const ClipboardData(text: command));

    if (!mounted) {
      return;
    }

    _showSnack('ADB force-stop command copied.');
  }

  Future<void> _closeAppForForceStopTest() async {
    setState(() {
      _status =
          'Closing app. For true force-stop, run scripts/force_stop.ps1 from PowerShell.';
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await SystemNavigator.pop();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
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
    final contact = _selectedContact;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Channel Test Lab'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _countingDown ? null : _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _HeroCard(),
                const SizedBox(height: 16),
                _StatusCard(status: _status),
                const SizedBox(height: 16),
                _ChannelParityCard(
                  whatsAppInstalled: _whatsAppInstalled,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('5 second WhatsApp test'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_contacts.isEmpty)
                        const Text(
                          'No approved contacts found. Add a consented contact first.',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        DropdownButtonFormField<NzSmsRecipient>(
                          value: contact,
                          decoration: const InputDecoration(
                            labelText: 'Approved contact',
                          ),
                          items: _contacts
                              .map(
                                (item) => DropdownMenuItem<NzSmsRecipient>(
                                  value: item,
                                  child: Text('${item.name} - ${item.number}'),
                                ),
                              )
                              .toList(),
                          onChanged: _countingDown
                              ? null
                              : (value) {
                                  setState(() => _selectedContact = value);
                                },
                        ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _testMessageController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Test message',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      if (_countingDown)
                        _CountdownCard(secondsRemaining: _secondsRemaining),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _countingDown
                                  ? null
                                  : _startFiveSecondWhatsAppTest,
                              icon: const Icon(CupertinoIcons.timer),
                              label: const Text('Start 5 Sec Test'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _countingDown ? _cancelFiveSecondTest : null,
                              icon: const Icon(CupertinoIcons.xmark_circle),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Channel shortcuts'),
                const SizedBox(height: 12),
                _LabButton(
                  icon: CupertinoIcons.paperplane_fill,
                  title: 'Open SMS Direct Send',
                  subtitle: 'Use the existing SMS send flow.',
                  onTap: () => _open(context, const DirectSmsScreen()),
                ),
                _LabButton(
                  icon: CupertinoIcons.arrow_up_right_square_fill,
                  title: 'Open WhatsApp Manual Handoff',
                  subtitle: 'Prepare one WhatsApp draft immediately.',
                  onTap: () => _open(context, const WhatsAppHandoffScreen()),
                ),
                _LabButton(
                  icon: CupertinoIcons.tray_full_fill,
                  title: 'Open Send Queue',
                  subtitle: 'Review queued and retryable work.',
                  onTap: () => _open(context, const SendQueueScreen()),
                ),
                _LabButton(
                  icon: CupertinoIcons.doc_text_search,
                  title: 'Open Send History',
                  subtitle: 'Check SMS and WhatsApp handoff logs.',
                  onTap: () => _open(context, const SendHistoryScreen()),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Force-stop tools'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'True Android force-stop must be done by ADB, not by the app itself.',
                        style: TextStyle(
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use this PowerShell command:',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SelectableText(
                        'adb shell am force-stop com.example.text_helper',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _copyForceStopCommand,
                        icon: const Icon(CupertinoIcons.doc_on_doc_fill),
                        label: const Text('Copy Force-Stop Command'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _closeAppForForceStopTest,
                        icon: const Icon(CupertinoIcons.square_arrow_down),
                        label: const Text('Close App for Test'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.lab_flask_solid,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Channel Test Lab',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Test SMS, RCS policy, WhatsApp handoff, 5-second draft timing, and force-stop behaviour from one place.',
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

class _ChannelParityCard extends StatelessWidget {
  const _ChannelParityCard({
    required this.whatsAppInstalled,
  });

  final bool whatsAppInstalled;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Channel parity'),
          const SizedBox(height: 12),
          const _ParityRow(
            label: 'SMS',
            value: 'Auto-send supported',
            ok: true,
          ),
          const _ParityRow(
            label: 'RCS',
            value:
                'No app-level auto-send API; use SMS fallback or manual flow',
            ok: false,
          ),
          _ParityRow(
            label: 'WhatsApp',
            value: whatsAppInstalled
                ? 'Manual handoff supported'
                : 'WhatsApp not detected',
            ok: whatsAppInstalled,
          ),
        ],
      ),
    );
  }
}

class _ParityRow extends StatelessWidget {
  const _ParityRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.info_circle_fill,
            color: ok ? const Color(0xFF16A34A) : const Color(0xFFF97316),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: CupertinoColors.label,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.secondsRemaining});

  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.timer_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Opening WhatsApp draft in $secondsRemaining seconds...',
              style: const TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabButton extends StatelessWidget {
  const _LabButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0A84FF), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward, size: 18),
              ],
            ),
          ),
        ),
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
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: CupertinoColors.label,
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
