import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nz_sms_recipient.dart';
import '../services/nz_recipient_store.dart';

class AutoReplyRulesScreen extends StatefulWidget {
  const AutoReplyRulesScreen({super.key});

  @override
  State<AutoReplyRulesScreen> createState() => _AutoReplyRulesScreenState();
}

class _AutoReplyRule {
  const _AutoReplyRule({
    required this.id,
    required this.keyword,
    required this.reply,
    required this.enabled,
    required this.cooldownMinutes,
  });

  final String id;
  final String keyword;
  final String reply;
  final bool enabled;
  final int cooldownMinutes;

  _AutoReplyRule copyWith({
    String? id,
    String? keyword,
    String? reply,
    bool? enabled,
    int? cooldownMinutes,
  }) {
    return _AutoReplyRule(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      reply: reply ?? this.reply,
      enabled: enabled ?? this.enabled,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
    );
  }

  factory _AutoReplyRule.fromJson(Map<String, dynamic> json) {
    return _AutoReplyRule(
      id: json['id'] as String? ?? '',
      keyword: json['keyword'] as String? ?? '',
      reply: json['reply'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      cooldownMinutes: json['cooldownMinutes'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'reply': reply,
      'enabled': enabled,
      'cooldownMinutes': cooldownMinutes,
    };
  }
}

class _PresetReply {
  const _PresetReply({
    required this.title,
    required this.keyword,
    required this.reply,
    required this.description,
    required this.icon,
  });

  final String title;
  final String keyword;
  final String reply;
  final String description;
  final IconData icon;
}

class _AutoReplyRulesScreenState extends State<AutoReplyRulesScreen> {
  static const String _rulesKey = 'text_helper_auto_reply_rules';
  static const String _allowedNumbersKey =
      'text_helper_auto_reply_allowed_numbers';
  static const String _masterEnabledKey =
      'text_helper_auto_reply_master_enabled';

  static const List<_PresetReply> _presets = [
    _PresetReply(
      title: 'Confirm',
      keyword: 'yes',
      reply: 'Thanks, confirmed.',
      description: 'Good for appointments and bookings.',
      icon: CupertinoIcons.check_mark_circled_solid,
    ),
    _PresetReply(
      title: 'Cancel',
      keyword: 'cancel',
      reply: 'No problem, I have marked this as cancelled.',
      description: 'Handles cancellation replies.',
      icon: CupertinoIcons.xmark_circle_fill,
    ),
    _PresetReply(
      title: 'Help',
      keyword: 'help',
      reply: 'Thanks for your message. I will get back to you soon.',
      description: 'Lets customers ask for help.',
      icon: CupertinoIcons.question_circle_fill,
    ),
    _PresetReply(
      title: 'Busy',
      keyword: 'busy',
      reply:
          'Thanks for your message. I am busy right now and will reply soon.',
      description: 'Useful while working or driving.',
      icon: CupertinoIcons.clock_fill,
    ),
  ];

  final NzRecipientStore _recipientStore = NzRecipientStore();

  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _testController = TextEditingController();

  List<_AutoReplyRule> _rules = <_AutoReplyRule>[];
  List<NzSmsRecipient> _approvedContacts = <NzSmsRecipient>[];

  bool _loading = true;
  bool _autoReplyEnabled = true;

  int _cooldownMinutes = 30;

  String _status =
      'Auto Reply is ready. Turn it on, choose quick replies, then test it.';

  @override
  void initState() {
    super.initState();

    _keywordController.text = 'yes';
    _replyController.text = 'Thanks, confirmed.';
    _testController.text = 'yes please';

    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _replyController.dispose();
    _testController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await _recipientStore.loadRecipients();
    final approved = contacts.where((contact) => contact.consented).toList();

    final rawRules = prefs.getString(_rulesKey);
    final rules = <_AutoReplyRule>[];

    if (rawRules != null && rawRules.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRules);

        if (decoded is List) {
          rules.addAll(
            decoded.whereType<Map>().map(
                  (item) => _AutoReplyRule.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
        }
      } catch (_) {}
    }

    if (rules.isEmpty) {
      rules.addAll(
        _presets.take(3).map(
              (preset) => _AutoReplyRule(
                id: 'preset-${preset.keyword}',
                keyword: preset.keyword,
                reply: preset.reply,
                enabled: true,
                cooldownMinutes: 30,
              ),
            ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _approvedContacts = approved;
      _rules = rules;
      _autoReplyEnabled = prefs.getBool(_masterEnabledKey) ?? true;
      _loading = false;
    });

    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final allowedNumbers = _approvedContacts
        .where((contact) => contact.consented)
        .map((contact) => contact.number)
        .toList();

    await prefs.setBool(_masterEnabledKey, _autoReplyEnabled);

    await prefs.setString(
      _rulesKey,
      jsonEncode(_rules.map((rule) => rule.toJson()).toList()),
    );

    await prefs.setString(
      _allowedNumbersKey,
      jsonEncode(allowedNumbers),
    );
  }

  Future<void> _toggleMasterSwitch(bool enabled) async {
    setState(() {
      _autoReplyEnabled = enabled;
      _status = enabled
          ? 'Auto Reply is on. Incoming SMS from approved contacts can be answered.'
          : 'Auto Reply is off. No automatic replies will be sent.';
    });

    await _save();
  }

  Future<void> _usePreset(_PresetReply preset) async {
    final existingIndex = _rules.indexWhere(
      (rule) => rule.keyword.toLowerCase() == preset.keyword.toLowerCase(),
    );

    final rule = _AutoReplyRule(
      id: existingIndex >= 0
          ? _rules[existingIndex].id
          : 'preset-${preset.keyword}',
      keyword: preset.keyword,
      reply: preset.reply,
      enabled: true,
      cooldownMinutes: 30,
    );

    setState(() {
      if (existingIndex >= 0) {
        final updated = [..._rules];
        updated[existingIndex] = rule;
        _rules = updated;
      } else {
        _rules = [rule, ..._rules];
      }

      _keywordController.text = preset.keyword;
      _replyController.text = preset.reply;
      _status = '${preset.title} preset saved.';
    });

    await _save();
  }

  Future<void> _addRule() async {
    final keyword = _keywordController.text.trim();
    final reply = _replyController.text.trim();

    if (keyword.isEmpty || reply.isEmpty) {
      _showSnack('Type a keyword and a reply.');
      return;
    }

    final existingIndex = _rules.indexWhere(
      (rule) => rule.keyword.toLowerCase() == keyword.toLowerCase(),
    );

    final rule = _AutoReplyRule(
      id: existingIndex >= 0
          ? _rules[existingIndex].id
          : 'rule-${DateTime.now().microsecondsSinceEpoch}',
      keyword: keyword,
      reply: reply,
      enabled: true,
      cooldownMinutes: _cooldownMinutes,
    );

    setState(() {
      if (existingIndex >= 0) {
        final updated = [..._rules];
        updated[existingIndex] = rule;
        _rules = updated;
        _status = 'Rule updated.';
      } else {
        _rules = [rule, ..._rules];
        _status = 'Rule added.';
      }
    });

    await _save();
  }

  Future<void> _toggleRule(_AutoReplyRule rule) async {
    setState(() {
      _rules = _rules
          .map(
            (item) => item.id == rule.id
                ? item.copyWith(enabled: !item.enabled)
                : item,
          )
          .toList();

      _status = rule.enabled ? 'Rule disabled.' : 'Rule enabled.';
    });

    await _save();
  }

  Future<void> _deleteRule(_AutoReplyRule rule) async {
    setState(() {
      _rules = _rules.where((item) => item.id != rule.id).toList();
      _status = 'Rule deleted.';
    });

    await _save();
  }

  void _editRule(_AutoReplyRule rule) {
    setState(() {
      _keywordController.text = rule.keyword;
      _replyController.text = rule.reply;
      _cooldownMinutes = rule.cooldownMinutes;
      _status = 'Editing "${rule.keyword}". Change the fields and tap Save.';
    });
  }

  _AutoReplyRule? _matchRule(String incoming) {
    final normalized = incoming.toLowerCase();

    for (final rule in _rules) {
      if (!rule.enabled) {
        continue;
      }

      final keyword = rule.keyword.trim().toLowerCase();

      if (keyword.isEmpty) {
        continue;
      }

      if (normalized.contains(keyword)) {
        return rule;
      }
    }

    return null;
  }

  void _testRules() {
    if (!_autoReplyEnabled) {
      setState(() {
        _status = 'Auto Reply is off. Turn it on before testing.';
      });
      return;
    }

    final incoming = _testController.text.trim();

    if (incoming.isEmpty) {
      _showSnack('Type a sample incoming message.');
      return;
    }

    final match = _matchRule(incoming);

    setState(() {
      _status = match == null
          ? 'No rule matched. No reply would be sent.'
          : 'Matched "${match.keyword}". Reply preview: ${match.reply}';
    });
  }

  Future<void> _resetRecommendedRules() async {
    setState(() {
      _rules = _presets
          .map(
            (preset) => _AutoReplyRule(
              id: 'preset-${preset.keyword}',
              keyword: preset.keyword,
              reply: preset.reply,
              enabled: true,
              cooldownMinutes: 30,
            ),
          )
          .toList();
      _status = 'Recommended quick replies restored.';
    });

    await _save();
  }

  String _previewForTest() {
    if (!_autoReplyEnabled) {
      return 'Auto Reply is off.';
    }

    final incoming = _testController.text.trim();

    if (incoming.isEmpty) {
      return 'Type a sample incoming message.';
    }

    final match = _matchRule(incoming);

    if (match == null) {
      return 'No reply will be sent.';
    }

    return match.reply;
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
    final enabledCount = _rules.where((rule) => rule.enabled).length;
    final hasApprovedContacts = _approvedContacts.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Auto Reply'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Restore recommended replies',
            onPressed: _resetRecommendedRules,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
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
                _SetupCard(
                  enabled: _autoReplyEnabled,
                  enabledRuleCount: enabledCount,
                  approvedContactCount: _approvedContacts.length,
                  onChanged: _toggleMasterSwitch,
                ),
                if (!hasApprovedContacts) ...[
                  const SizedBox(height: 12),
                  const _WarningCard(
                    title: 'No approved contacts yet',
                    text:
                        'Auto Reply will not send until at least one contact is approved. Add contacts and mark consent as approved.',
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionTitle('Quick replies'),
                const SizedBox(height: 12),
                ..._presets.map(
                  (preset) => _PresetCard(
                    preset: preset,
                    onUse: () => _usePreset(preset),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Try it first'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _testController,
                        decoration: const InputDecoration(
                          labelText: 'Sample incoming SMS',
                          helperText: 'Example: yes please, cancel, help',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _ReplyPreview(text: _previewForTest()),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _testRules,
                        icon: const Icon(CupertinoIcons.lab_flask_solid),
                        label: const Text('Test Auto Reply'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Custom reply'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _keywordController,
                        decoration: const InputDecoration(
                          labelText: 'When incoming SMS contains',
                          helperText: 'Example: quote, price, tomorrow',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _replyController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reply with',
                          helperText: 'This SMS is sent automatically.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _cooldownMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Do not repeat for',
                        ),
                        items: const [
                          DropdownMenuItem<int>(
                            value: 5,
                            child: Text('5 minutes'),
                          ),
                          DropdownMenuItem<int>(
                            value: 15,
                            child: Text('15 minutes'),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text('30 minutes'),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text('1 hour'),
                          ),
                          DropdownMenuItem<int>(
                            value: 180,
                            child: Text('3 hours'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() => _cooldownMinutes = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addRule,
                        icon:
                            const Icon(CupertinoIcons.check_mark_circled_solid),
                        label: const Text('Save Reply Rule'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Saved replies ($enabledCount active)'),
                const SizedBox(height: 12),
                if (_rules.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No replies saved yet.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ..._rules.map(
                    (rule) => _RuleCard(
                      rule: rule,
                      onEdit: () => _editRule(rule),
                      onToggle: () => _toggleRule(rule),
                      onDelete: () => _deleteRule(rule),
                    ),
                  ),
                const SizedBox(height: 12),
                const _HowItWorksCard(),
              ],
            ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.enabled,
    required this.enabledRuleCount,
    required this.approvedContactCount,
    required this.onChanged,
  });

  final bool enabled;
  final int enabledRuleCount;
  final int approvedContactCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onChanged,
            title: Text(
              enabled ? 'Auto Reply is ON' : 'Auto Reply is OFF',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              enabled
                  ? 'Text Helper can answer matching SMS messages.'
                  : 'No automatic replies will be sent.',
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  value: enabledRuleCount.toString(),
                  label: 'Active replies',
                  color: const Color(0xFF0A84FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniMetric(
                  value: approvedContactCount.toString(),
                  label: 'Approved contacts',
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.onUse,
  });

  final _PresetReply preset;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            preset.icon,
            color: const Color(0xFF0A84FF),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trigger: "${preset.keyword}"',
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  preset.description,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preset.reply,
                  style: const TextStyle(
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onUse,
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.bubble_left_bubble_right_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF0A84FF),
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

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final _AutoReplyRule rule;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rule.enabled
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.pause_circle_fill,
                color: rule.enabled
                    ? const Color(0xFF16A34A)
                    : CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'When SMS contains "${rule.keyword}"',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                rule.enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: rule.enabled
                      ? const Color(0xFF16A34A)
                      : CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rule.reply,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cooldown: ${rule.cooldownMinutes} minutes',
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(CupertinoIcons.pencil),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    rule.enabled
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                  ),
                  label: Text(rule.enabled ? 'Disable' : 'Enable'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(CupertinoIcons.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('How Auto Reply works'),
          SizedBox(height: 12),
          _StepRow(
            number: '1',
            text: 'Incoming SMS arrives.',
          ),
          _StepRow(
            number: '2',
            text: 'Text Helper checks if the sender is an approved contact.',
          ),
          _StepRow(
            number: '3',
            text:
                'If the message contains a saved keyword, Text Helper sends the reply.',
          ),
          _StepRow(
            number: '4',
            text: 'Cooldown prevents repeat replies to the same keyword.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: Color(0xFF0A84FF),
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFF97316),
          ),
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
                const SizedBox(height: 6),
                Text(
                  text,
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
            CupertinoIcons.arrowshape_turn_up_left_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'Auto Reply',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Set simple SMS replies for confirmations, cancellations, help requests, and custom keywords.',
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
