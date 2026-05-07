import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/scheduled_message.dart';
import '../repositories/scheduled_messages_repository.dart';

class ScheduledSmsScreen extends StatefulWidget {
  const ScheduledSmsScreen({super.key});

  @override
  State<ScheduledSmsScreen> createState() => _ScheduledSmsScreenState();
}

class _ScheduledSmsScreenState extends State<ScheduledSmsScreen> {
  final ScheduledMessagesRepository _repository = ScheduledMessagesRepository();

  final TextEditingController _messageController = TextEditingController(
    text: 'Quick reminder: please confirm when you get this.',
  );

  final List<String> _groups = const [
    'Family',
    'Work',
    'Test Send',
  ];

  String _selectedGroup = 'Family';
  String _selectedDate = 'Today';
  String _selectedTime = '6:30 PM';

  List<ScheduledMessage> _messages = <ScheduledMessage>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _repository.loadMessages();

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  Future<void> _saveDraft() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a message before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final message = ScheduledMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      groupName: _selectedGroup,
      message: text,
      scheduledLabel: '$_selectedDate • $_selectedTime',
      status: 'Draft',
    );

    await _repository.addMessage(message);
    await _loadMessages();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheduled SMS draft saved locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteMessage(ScheduledMessage message) async {
    await _repository.deleteMessage(message.id);
    await _loadMessages();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheduled draft deleted locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetMessages() async {
    await _repository.resetMessages();
    await _loadMessages();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheduled messages reset to sample data.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectGroup() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Select recipient group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ..._groups.map(
                (group) => ListTile(
                  leading: const Icon(CupertinoIcons.person_2_fill),
                  title: Text(group),
                  trailing: group == _selectedGroup
                      ? const Icon(CupertinoIcons.check_mark_circled_solid)
                      : null,
                  onTap: () => Navigator.of(context).pop(group),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _selectedGroup = result);
    }
  }

  void _cycleDate() {
    setState(() {
      _selectedDate = switch (_selectedDate) {
        'Today' => 'Tomorrow',
        'Tomorrow' => 'Friday',
        _ => 'Today',
      };
    });
  }

  void _cycleTime() {
    setState(() {
      _selectedTime = switch (_selectedTime) {
        '6:30 PM' => '9:00 AM',
        '9:00 AM' => '12:00 PM',
        _ => '6:30 PM',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewLabel = '$_selectedDate • $_selectedTime';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Scheduled SMS'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _resetMessages,
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Reset scheduled messages',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _HeroPanel(
                  totalMessages: _messages.length,
                  groupName: _selectedGroup,
                  scheduledLabel: previewLabel,
                ),
                const SizedBox(height: 20),
                const _SectionTitle(title: 'Message draft'),
                const SizedBox(height: 12),
                _ComposerCard(
                  controller: _messageController,
                  selectedGroup: _selectedGroup,
                  selectedDate: _selectedDate,
                  selectedTime: _selectedTime,
                  onGroupTap: _selectGroup,
                  onDateTap: _cycleDate,
                  onTimeTap: _cycleTime,
                  onSave: _saveDraft,
                ),
                const SizedBox(height: 20),
                const _SectionTitle(title: 'Saved queue'),
                const SizedBox(height: 12),
                if (_messages.isEmpty)
                  const _EmptyQueueCard()
                else
                  ..._messages.map(
                    (message) => _QueuedMessageCard(
                      message: message,
                      onDelete: () => _deleteMessage(message),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.totalMessages,
    required this.groupName,
    required this.scheduledLabel,
  });

  final int totalMessages;
  final String groupName;
  final String scheduledLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Feature 02',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Persistent scheduled drafts.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$totalMessages saved locally. No real SMS sending is connected yet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: groupName, label: 'group'),
              const SizedBox(width: 12),
              _HeroMetric(value: scheduledLabel, label: 'time'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.controller,
    required this.selectedGroup,
    required this.selectedDate,
    required this.selectedTime,
    required this.onGroupTap,
    required this.onDateTap,
    required this.onTimeTap,
    required this.onSave,
  });

  final TextEditingController controller;
  final String selectedGroup;
  final String selectedDate;
  final String selectedTime;
  final VoidCallback onGroupTap;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          _PickerRow(
            icon: CupertinoIcons.person_2_fill,
            label: 'Group',
            value: selectedGroup,
            onTap: onGroupTap,
          ),
          const Divider(height: 24),
          _PickerRow(
            icon: CupertinoIcons.calendar,
            label: 'Date',
            value: selectedDate,
            onTap: onDateTap,
          ),
          const Divider(height: 24),
          _PickerRow(
            icon: CupertinoIcons.clock_fill,
            label: 'Time',
            value: selectedTime,
            onTap: onTimeTap,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Write message...',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(CupertinoIcons.tray_arrow_down_fill),
            label: const Text('Save scheduled draft'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0A84FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_forward, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QueuedMessageCard extends StatelessWidget {
  const _QueuedMessageCard({
    required this.message,
    required this.onDelete,
  });

  final ScheduledMessage message;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(message.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          CupertinoIcons.trash_fill,
          color: Colors.white,
        ),
      ),
      child: _SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBubble(
              icon: CupertinoIcons.chat_bubble_text_fill,
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF0A84FF),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.groupName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.scheduledLabel,
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.message,
                    style: const TextStyle(
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message.status,
              style: const TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQueueCard extends StatelessWidget {
  const _EmptyQueueCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        children: [
          _IconBubble(
            icon: CupertinoIcons.chat_bubble_text,
            backgroundColor: Color(0xFFF3F4F6),
            foregroundColor: Color(0xFF111827),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'No scheduled drafts saved yet.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: foregroundColor, size: 22),
    );
  }
}
