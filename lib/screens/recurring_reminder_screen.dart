import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/nz_sms_recipient.dart';
import '../services/native_sms_service.dart';
import '../services/nz_recipient_store.dart';

class RecurringReminderScreen extends StatefulWidget {
  const RecurringReminderScreen({super.key});

  @override
  State<RecurringReminderScreen> createState() =>
      _RecurringReminderScreenState();
}

class _RecurringReminderScreenState extends State<RecurringReminderScreen> {
  final NativeSmsService _smsService = NativeSmsService();
  final NzRecipientStore _store = NzRecipientStore();

  final TextEditingController _messageController = TextEditingController(
    text: 'Test reminder from Text Helper.',
  );

  List<NzSmsRecipient> _contacts = <NzSmsRecipient>[];
  NzSmsRecipient? _selectedContact;

  Timer? _timer;
  DateTime _startAt = DateTime.now().add(const Duration(minutes: 1));

  bool _isLoading = true;
  bool _isRunning = false;
  bool _isSending = false;

  int _sentCount = 0;
  int _maxSends = 5;
  DateTime? _nextSendAt;
  String _status = 'Not running';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await _store.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _contacts = approved;
      _selectedContact = approved.isEmpty ? null : approved.first;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startAt.hour,
        _startAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _startReminderLoop() {
    final contact = _selectedContact;
    final message = _messageController.text.trim();

    if (contact == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a contact and enter a message first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _timer?.cancel();

    setState(() {
      _isRunning = true;
      _sentCount = 0;
      _nextSendAt =
          _startAt.isBefore(DateTime.now()) ? DateTime.now() : _startAt;
      _status = 'Running. Waiting for next send.';
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickReminderLoop(),
    );
  }

  Future<void> _tickReminderLoop() async {
    if (!_isRunning || _isSending) {
      return;
    }

    final nextSendAt = _nextSendAt;
    if (nextSendAt == null || DateTime.now().isBefore(nextSendAt)) {
      return;
    }

    if (_sentCount >= _maxSends) {
      _forceStop(status: 'Stopped after $_maxSends test sends.');
      return;
    }

    await _sendReminder();
  }

  Future<void> _sendReminder() async {
    final contact = _selectedContact;
    final baseMessage = _messageController.text.trim();

    if (contact == null || baseMessage.isEmpty) {
      _forceStop(status: 'Stopped: missing contact or message.');
      return;
    }

    setState(() {
      _isSending = true;
      _status = 'Sending test reminder ${_sentCount + 1}...';
    });

    try {
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final message =
          '$baseMessage\n\nTest reminder ${_sentCount + 1} at $time';

      await _smsService.sendSms(
        phoneNumber: contact.number,
        message: message,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sentCount += 1;
        _nextSendAt = DateTime.now().add(const Duration(minutes: 1));
        _status = 'Sent $_sentCount/$_maxSends. Next send in 1 minute.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _forceStop(status: 'Stopped: send failed - $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _forceStop({String status = 'Force stopped.'}) {
    _timer?.cancel();

    setState(() {
      _isRunning = false;
      _isSending = false;
      _nextSendAt = null;
      _status = status;
    });
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final contact = _selectedContact;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Reminder Test'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _isRunning ? null : _loadContacts,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroCard(
                  isRunning: _isRunning,
                  sentCount: _sentCount,
                  maxSends: _maxSends,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Contact'),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No approved contacts found. Add your test number in Contacts first.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._contacts.map(
                    (item) => _ContactCard(
                      contact: item,
                      selected: item.id == contact?.id,
                      disabled: _isRunning,
                      onTap: () {
                        if (_isRunning) {
                          return;
                        }

                        setState(() => _selectedContact = item);
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle('Start date and time'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.calendar),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDateTime(_startAt),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isRunning ? null : _pickDate,
                              icon: const Icon(CupertinoIcons.calendar),
                              label: const Text('Date'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isRunning ? null : _pickTime,
                              icon: const Icon(CupertinoIcons.clock),
                              label: const Text('Time'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Message'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isRunning,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write reminder text...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Repeat limit'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Send once per minute',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _maxSends,
                        onChanged: _isRunning
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() => _maxSends = value);
                              },
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 text')),
                          DropdownMenuItem(value: 3, child: Text('3 texts')),
                          DropdownMenuItem(value: 5, child: Text('5 texts')),
                          DropdownMenuItem(value: 10, child: Text('10 texts')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _StatusCard(
                  status: _status,
                  nextSendAt: _nextSendAt,
                  formatter: _formatDateTime,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isRunning ? null : _startReminderLoop,
                  icon: const Icon(CupertinoIcons.play_fill),
                  label: const Text('START TEST REMINDERS'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isRunning ? () => _forceStop() : null,
                  icon: const Icon(CupertinoIcons.stop_fill),
                  label: const Text('FORCE STOP'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SafetyNote(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isRunning,
    required this.sentCount,
    required this.maxSends,
  });

  final bool isRunning;
  final int sentCount;
  final int maxSends;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRunning ? const Color(0xFF0A84FF) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        isRunning
            ? 'Reminder test running\n$sentCount/$maxSends sent'
            : 'Reminder test\n1 text per minute',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 27,
          height: 1.12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final NzSmsRecipient contact;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled && !selected ? 0.55 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: _SurfaceCard(
          borderColor: selected ? const Color(0xFF0A84FF) : null,
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.person_fill,
                color: selected
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
                  ],
                ),
              ),
              if (selected)
                const Text(
                  'Selected',
                  style: TextStyle(
                    color: Color(0xFF0A84FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.nextSendAt,
    required this.formatter,
  });

  final String status;
  final DateTime? nextSendAt;
  final String Function(DateTime value) formatter;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (nextSendAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next: ${formatter(nextSendAt!)}',
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'This sends real SMS messages once per minute while the app is open. Use your own test number first. Tap FORCE STOP to stop the loop.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w600,
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
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: borderColor == null
            ? null
            : Border.all(
                color: borderColor!,
                width: 2,
              ),
      ),
      child: child,
    );
  }
}
