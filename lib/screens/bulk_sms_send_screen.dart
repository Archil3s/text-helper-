import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nz_sms_recipient.dart';
import '../services/nz_recipient_store.dart';

class BulkSmsSendScreen extends StatefulWidget {
  const BulkSmsSendScreen({super.key});

  @override
  State<BulkSmsSendScreen> createState() => _BulkSmsSendScreenState();
}

class _BulkSmsSendScreenState extends State<BulkSmsSendScreen> {
  static const MethodChannel _smsChannel = MethodChannel(
    'text_helper/native_sms',
  );

  final NzRecipientStore _recipientStore = NzRecipientStore();
  final TextEditingController _messageController = TextEditingController();

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  Set<String> _selectedIds = <String>{};
  List<String> _logs = <String>[];

  bool _loading = true;
  bool _sending = false;

  int _delaySeconds = 5;
  int _sent = 0;
  int _failed = 0;

  String _status =
      'Select approved contacts, preview the message, then send slowly.';

  @override
  void initState() {
    super.initState();
    _messageController.text = 'Hi {name}, this is a reminder from Text Helper.';
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await _recipientStore.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approved;
      _selectedIds = approved.map((contact) => contact.id).toSet();
      _loading = false;
    });
  }

  String _renderMessage(NzSmsRecipient contact) {
    return _messageController.text
        .replaceAll('{name}', contact.name)
        .replaceAll('{number}', contact.number);
  }

  Future<void> _sendBulk() async {
    final targets = _contacts
        .where((contact) => _selectedIds.contains(contact.id))
        .toList();

    if (targets.isEmpty) {
      _showSnack('Select at least one approved contact.');
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      _showSnack('Message is required.');
      return;
    }

    setState(() {
      _sending = true;
      _sent = 0;
      _failed = 0;
      _logs = <String>[];
      _status = 'Bulk send started. Do not close the app.';
    });

    for (var index = 0; index < targets.length; index++) {
      if (!mounted) {
        return;
      }

      final contact = targets[index];
      final message = _renderMessage(contact);
      final reminderId =
          'bulk-${DateTime.now().microsecondsSinceEpoch}-${contact.id}';

      setState(() {
        _status = 'Sending ${index + 1} of ${targets.length}: ${contact.name}';
      });

      try {
        final result = await _smsChannel.invokeMethod<bool>(
          'sendSms',
          <String, Object?>{
            'phoneNumber': contact.number,
            'message': message,
            'reminderId': reminderId,
          },
        );

        if (result == true) {
          setState(() {
            _sent += 1;
            _log('Sent to ${contact.name} (${contact.number})');
          });
        } else {
          setState(() {
            _failed += 1;
            _log('Failed to send to ${contact.name}');
          });
        }
      } catch (error) {
        setState(() {
          _failed += 1;
          _log('Error for ${contact.name}: $error');
        });
      }

      if (index < targets.length - 1) {
        await Future<void>.delayed(Duration(seconds: _delaySeconds));
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sending = false;
      _status = 'Bulk send complete. Sent $_sent, failed $_failed.';
    });
  }

  void _toggleContact(NzSmsRecipient contact) {
    setState(() {
      final next = {..._selectedIds};
      if (next.contains(contact.id)) {
        next.remove(contact.id);
      } else {
        next.add(contact.id);
      }
      _selectedIds = next;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _contacts.map((contact) => contact.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds = <String>{};
    });
  }

  void _log(String value) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '$time  $value');
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
    final selectedContacts = _contacts
        .where((contact) => _selectedIds.contains(contact.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Bulk Send'),
        centerTitle: false,
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
                _SurfaceCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          value: selectedContacts.length.toString(),
                          label: 'Selected',
                          color: const Color(0xFF0A84FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          value: _sent.toString(),
                          label: 'Sent',
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          value: _failed.toString(),
                          label: 'Failed',
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Message'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Bulk SMS template',
                          helperText: 'Use {name} and {number}.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _delaySeconds,
                        decoration: const InputDecoration(
                          labelText: 'Delay between messages',
                        ),
                        items: const [
                          DropdownMenuItem<int>(
                            value: 3,
                            child: Text('3 seconds'),
                          ),
                          DropdownMenuItem<int>(
                            value: 5,
                            child: Text('5 seconds'),
                          ),
                          DropdownMenuItem<int>(
                            value: 10,
                            child: Text('10 seconds'),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text('30 seconds'),
                          ),
                        ],
                        onChanged: _sending
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _delaySeconds = value);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Approved recipients'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _selectAll,
                        icon: const Icon(CupertinoIcons.check_mark_circled),
                        label: const Text('Select All'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _clearSelection,
                        icon: const Icon(CupertinoIcons.clear_circled),
                        label: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No approved contacts found. Add contacts and mark consent as approved first.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ..._contacts.map(
                    (contact) => _ContactCard(
                      contact: contact,
                      selected: _selectedIds.contains(contact.id),
                      preview: _renderMessage(contact),
                      disabled: _sending,
                      onTap: () => _toggleContact(contact),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending ? null : _sendBulk,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.person_3_fill),
                  label: Text(_sending ? 'Sending...' : 'Start Bulk Send'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.selected,
    required this.preview,
    required this.disabled,
    required this.onTap,
  });

  final NzSmsRecipient contact;
  final bool selected;
  final String preview;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? const Color(0xFF16A34A)
                  : CupertinoColors.systemGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.number,
                    style: const TextStyle(
                      color: Color(0xFF0A84FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
            CupertinoIcons.person_3_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Bulk Send',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send SMS to approved contacts in a controlled, throttled batch.',
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
      margin: const EdgeInsets.only(bottom: 12),
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
