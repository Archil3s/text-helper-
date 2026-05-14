import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ScheduleCenterScreen extends StatefulWidget {
  const ScheduleCenterScreen({super.key});

  @override
  State<ScheduleCenterScreen> createState() => _ScheduleCenterScreenState();
}

class _ScheduleCenterScreenState extends State<ScheduleCenterScreen> {
  static const _storageKey = 'schedule_center_items_v2';

  final _searchController = TextEditingController();
  final List<ScheduleItem> _items = [];

  bool _loading = true;
  String _query = '';
  ScheduleFilter _filter = ScheduleFilter.due;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_storageKey) ?? const <String>[];
    final loaded = <ScheduleItem>[];

    for (final raw in rawItems) {
      try {
        loaded.add(
            ScheduleItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip broken local records rather than blocking the screen.
      }
    }

    loaded.sort(_sortScheduleItems);

    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(loaded);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  List<ScheduleItem> get _visibleItems {
    final now = DateTime.now();

    final filtered = _items.where((item) {
      final matchesQuery = _query.isEmpty ||
          [
            item.recipientName,
            item.phone,
            item.message,
            item.label,
            item.priority.name,
            item.status.name,
          ].join(' ').toLowerCase().contains(_query);

      if (!matchesQuery) return false;

      return switch (_filter) {
        ScheduleFilter.due => item.status == ScheduleStatus.scheduled &&
            !item.scheduledAt.isAfter(now),
        ScheduleFilter.upcoming => item.status == ScheduleStatus.scheduled &&
            item.scheduledAt.isAfter(now),
        ScheduleFilter.sent => item.status == ScheduleStatus.sent,
        ScheduleFilter.cancelled => item.status == ScheduleStatus.cancelled,
        ScheduleFilter.all => true,
      };
    }).toList();

    filtered.sort(_sortScheduleItems);
    return filtered;
  }

  int get _dueCount {
    final now = DateTime.now();
    return _items
        .where((item) =>
            item.status == ScheduleStatus.scheduled &&
            !item.scheduledAt.isAfter(now))
        .length;
  }

  int get _upcomingCount {
    final now = DateTime.now();
    return _items
        .where((item) =>
            item.status == ScheduleStatus.scheduled &&
            item.scheduledAt.isAfter(now))
        .length;
  }

  int get _sentCount =>
      _items.where((item) => item.status == ScheduleStatus.sent).length;

  int get _cancelledCount =>
      _items.where((item) => item.status == ScheduleStatus.cancelled).length;

  Future<void> _upsert({ScheduleItem? existing}) async {
    final result = await showModalBottomSheet<ScheduleItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ScheduleEditorSheet(existing: existing),
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = _items.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
      _items.sort(_sortScheduleItems);
    });

    await _save();
  }

  Future<void> _markSent(ScheduleItem item) async {
    setState(() => _replaceItem(item.copyWith(status: ScheduleStatus.sent)));
    await _save();
  }

  Future<void> _cancel(ScheduleItem item) async {
    setState(
        () => _replaceItem(item.copyWith(status: ScheduleStatus.cancelled)));
    await _save();
  }

  Future<void> _duplicate(ScheduleItem item) async {
    final now = DateTime.now();
    final copy = item.copyWith(
      id: now.microsecondsSinceEpoch.toString(),
      scheduledAt: now.add(const Duration(hours: 1)),
      status: ScheduleStatus.scheduled,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _items.add(copy);
      _items.sort(_sortScheduleItems);
    });

    await _save();
  }

  Future<void> _openSms(ScheduleItem item) async {
    final uri = Uri(
      scheme: 'sms',
      path: item.phone,
      queryParameters: {'body': item.message},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the SMS app.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('SMS opened. Mark it sent after sending.'),
        action: SnackBarAction(
          label: 'Mark sent',
          onPressed: () => _markSent(item),
        ),
      ),
    );
  }

  void _replaceItem(ScheduleItem updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _items[index] = updated.copyWith(updatedAt: DateTime.now());
    _items.sort(_sortScheduleItems);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Schedule Center'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _load,
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          IconButton(
            tooltip: 'New schedule',
            onPressed: () => _upsert(),
            icon: const Icon(CupertinoIcons.calendar_badge_plus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsert(),
        icon: const Icon(CupertinoIcons.calendar_badge_plus),
        label: const Text('New schedule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                  children: [
                    _HeroStatsCard(
                      dueCount: _dueCount,
                      upcomingCount: _upcomingCount,
                      sentCount: _sentCount,
                      cancelledCount: _cancelledCount,
                    ),
                    const SizedBox(height: 16),
                    _SearchBox(controller: _searchController),
                    const SizedBox(height: 12),
                    _FilterBar(
                      selected: _filter,
                      dueCount: _dueCount,
                      upcomingCount: _upcomingCount,
                      sentCount: _sentCount,
                      cancelledCount: _cancelledCount,
                      onChanged: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 16),
                    if (visibleItems.isEmpty)
                      const _EmptyState()
                    else
                      ...visibleItems.map(
                        (item) => _ScheduleCard(
                          item: item,
                          onOpenSms: () => _openSms(item),
                          onEdit: () => _upsert(existing: item),
                          onMarkSent: () => _markSent(item),
                          onCancel: () => _cancel(item),
                          onDuplicate: () => _duplicate(item),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

enum ScheduleStatus { scheduled, sent, cancelled }

enum SchedulePriority { low, normal, high, urgent }

enum ScheduleFilter { due, upcoming, sent, cancelled, all }

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.message,
    required this.label,
    required this.scheduledAt,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String recipientName;
  final String phone;
  final String message;
  final String label;
  final DateTime scheduledAt;
  final SchedulePriority priority;
  final ScheduleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDue {
    final now = DateTime.now();
    return status == ScheduleStatus.scheduled && !scheduledAt.isAfter(now);
  }

  ScheduleItem copyWith({
    String? id,
    String? recipientName,
    String? phone,
    String? message,
    String? label,
    DateTime? scheduledAt,
    SchedulePriority? priority,
    ScheduleStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      message: message ?? this.message,
      label: label ?? this.label,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientName': recipientName,
        'phone': phone,
        'message': message,
        'label': label,
        'scheduledAt': scheduledAt.toIso8601String(),
        'priority': priority.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    return ScheduleItem(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      recipientName: json['recipientName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      message: json['message'] as String? ?? '',
      label: json['label'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
      priority: SchedulePriority.values.firstWhere(
        (priority) => priority.name == json['priority'],
        orElse: () => SchedulePriority.normal,
      ),
      status: ScheduleStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ScheduleStatus.scheduled,
      ),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
    );
  }
}

class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({this.existing});

  final ScheduleItem? existing;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  late final TextEditingController _labelController;
  late DateTime _scheduledAt;
  late SchedulePriority _priority;

  static const _templates = [
    'Hi, this is a quick reminder.',
    'Just checking in — please reply when you can.',
    'Your appointment reminder is coming up.',
    'Thanks. I will follow up again soon.',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController =
        TextEditingController(text: existing?.recipientName ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _messageController = TextEditingController(text: existing?.message ?? '');
    _labelController = TextEditingController(text: existing?.label ?? '');
    _scheduledAt = existing?.scheduledAt ??
        DateTime.now().add(const Duration(minutes: 30));
    _priority = existing?.priority ?? SchedulePriority.normal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _applyTemplate(String template) {
    final current = _messageController.text.trim();
    _messageController.text =
        current.isEmpty ? template : '$current\n$template';
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    if (!_scheduledAt.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }

    final existing = widget.existing;

    Navigator.of(context).pop(
      ScheduleItem(
        id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
        recipientName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        message: _messageController.text.trim(),
        label: _labelController.text.trim(),
        scheduledAt: _scheduledAt,
        priority: _priority,
        status: ScheduleStatus.scheduled,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetHandle(),
            Text(
              widget.existing == null ? 'New schedule' : 'Edit schedule',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Recipient name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Phone is required';
                if (text.replaceAll(RegExp(r'[^0-9+]'), '').length < 7) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'appointment, follow-up, urgent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Message is required'
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates
                  .map(
                    (template) => ActionChip(
                      label: Text(template),
                      onPressed: () => _applyTemplate(template),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SchedulePriority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: SchedulePriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(CupertinoIcons.calendar),
                    label: Text(_formatDate(_scheduledAt)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(CupertinoIcons.time),
                    label: Text(_formatTime(_scheduledAt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _relativeTime(_scheduledAt),
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(CupertinoIcons.check_mark),
              label: const Text('Save schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatsCard extends StatelessWidget {
  const _HeroStatsCard({
    required this.dueCount,
    required this.upcomingCount,
    required this.sentCount,
    required this.cancelledCount,
  });

  final int dueCount;
  final int upcomingCount;
  final int sentCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.calendar, color: Colors.white, size: 34),
          const SizedBox(height: 14),
          const Text(
            'Schedule Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track due messages, upcoming sends, and completed communication from one visual queue.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(label: '$dueCount due'),
              _StatPill(label: '$upcomingCount upcoming'),
              _StatPill(label: '$sentCount sent'),
              _StatPill(label: '$cancelledCount cancelled'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.search),
        hintText: 'Search schedules, names, numbers, labels',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.dueCount,
    required this.upcomingCount,
    required this.sentCount,
    required this.cancelledCount,
    required this.onChanged,
  });

  final ScheduleFilter selected;
  final int dueCount;
  final int upcomingCount;
  final int sentCount;
  final int cancelledCount;
  final ValueChanged<ScheduleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = {
      ScheduleFilter.due: 'Due ($dueCount)',
      ScheduleFilter.upcoming: 'Upcoming ($upcomingCount)',
      ScheduleFilter.sent: 'Sent ($sentCount)',
      ScheduleFilter.cancelled: 'Cancelled ($cancelledCount)',
      ScheduleFilter.all: 'All',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ScheduleFilter.values.map((filter) {
        return FilterChip(
          label: Text(labels[filter]!),
          selected: selected == filter,
          onSelected: (_) => onChanged(filter),
        );
      }).toList(),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.onOpenSms,
    required this.onEdit,
    required this.onMarkSent,
    required this.onCancel,
    required this.onDuplicate,
  });

  final ScheduleItem item;
  final VoidCallback onOpenSms;
  final VoidCallback onEdit;
  final VoidCallback onMarkSent;
  final VoidCallback onCancel;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final active = item.status == ScheduleStatus.scheduled;

    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PriorityDot(priority: item.priority),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.recipientName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(item: item),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.phone,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(item.scheduledAt)} at ${_formatTime(item.scheduledAt)} • ${_relativeTime(item.scheduledAt)}',
            style: TextStyle(
              color: item.isDue
                  ? const Color(0xFFDC2626)
                  : CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.label.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Chip(label: item.label),
          ],
          const SizedBox(height: 10),
          Text(item.message, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: active ? onOpenSms : null,
                icon: const Icon(CupertinoIcons.chat_bubble_text),
                label: Text(item.isDue ? 'Open SMS now' : 'Open SMS'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: active ? onMarkSent : null,
                icon: const Icon(CupertinoIcons.check_mark),
                label: const Text('Sent'),
              ),
              OutlinedButton.icon(
                onPressed: active ? onCancel : null,
                icon: const Icon(CupertinoIcons.xmark),
                label: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(CupertinoIcons.square_on_square),
                label: const Text('Duplicate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final label = switch (item.status) {
      ScheduleStatus.scheduled => item.isDue ? 'Due' : 'Scheduled',
      ScheduleStatus.sent => 'Sent',
      ScheduleStatus.cancelled => 'Cancelled',
    };

    final color = switch (item.status) {
      ScheduleStatus.scheduled =>
        item.isDue ? const Color(0xFFDC2626) : const Color(0xFF0A84FF),
      ScheduleStatus.sent => const Color(0xFF16A34A),
      ScheduleStatus.cancelled => const Color(0xFF6B7280),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final SchedulePriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      SchedulePriority.low => const Color(0xFF6B7280),
      SchedulePriority.normal => const Color(0xFF0A84FF),
      SchedulePriority.high => const Color(0xFFF59E0B),
      SchedulePriority.urgent => const Color(0xFFDC2626),
    };

    return Tooltip(
      message: priority.name,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        children: [
          Icon(CupertinoIcons.calendar_badge_plus,
              size: 38, color: Color(0xFF0A84FF)),
          SizedBox(height: 10),
          Text(
            'No schedules here',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Create a schedule or change the filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0A84FF),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

int _sortScheduleItems(ScheduleItem a, ScheduleItem b) {
  final statusCompare = _statusRank(a).compareTo(_statusRank(b));
  if (statusCompare != 0) return statusCompare;

  final priorityCompare =
      _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
  if (priorityCompare != 0) return priorityCompare;

  return a.scheduledAt.compareTo(b.scheduledAt);
}

int _statusRank(ScheduleItem item) {
  if (item.status == ScheduleStatus.scheduled && item.isDue) return 0;
  if (item.status == ScheduleStatus.scheduled) return 1;
  if (item.status == ScheduleStatus.sent) return 2;
  return 3;
}

int _priorityRank(SchedulePriority priority) {
  return switch (priority) {
    SchedulePriority.low => 0,
    SchedulePriority.normal => 1,
    SchedulePriority.high => 2,
    SchedulePriority.urgent => 3,
  };
}

String _formatDate(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _relativeTime(DateTime dateTime) {
  final diff = dateTime.difference(DateTime.now());
  final abs = diff.abs();

  late final int amount;
  late final String unit;

  if (abs.inDays >= 1) {
    amount = abs.inDays;
    unit = amount == 1 ? 'day' : 'days';
  } else if (abs.inHours >= 1) {
    amount = abs.inHours;
    unit = amount == 1 ? 'hour' : 'hours';
  } else {
    amount = abs.inMinutes < 1 ? 1 : abs.inMinutes;
    unit = amount == 1 ? 'minute' : 'minutes';
  }

  return diff.isNegative ? '$amount $unit overdue' : 'in $amount $unit';
}
