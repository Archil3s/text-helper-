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

class _AutoReplyRulesScreenState extends State<AutoReplyRulesScreen> {
  static const String _rulesKey = 'text_helper_auto_reply_rules';
  static const String _allowedNumbersKey =
      'text_helper_auto_reply_allowed_numbers';

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
      'Auto Reply only replies to approved contacts and uses cooldown protection.';

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
        const [
          _AutoReplyRule(
            id: 'default-yes',
            keyword: 'yes',
            reply: 'Thanks, confirmed.',
            enabled: true,
            cooldownMinutes: 30,
          ),
          _AutoReplyRule(
            id: 'default-cancel',
            keyword: 'cancel',
            reply: 'No problem, I have marked this as cancelled.',
            enabled: true,
            cooldownMinutes: 30,
          ),
          _AutoReplyRule(
            id: 'default-help',
            keyword: 'help',
            reply: 'Thanks for your message. I will get back to you soon.',
            enabled: true,
            cooldownMinutes: 30,
          ),
        ],
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _approvedContacts = approved;
      _rules = rules;
      _loading = false;
    });

    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final enabledRules = _autoReplyEnabled
        ? _rules
        : _rules.map((rule) => rule.copyWith(enabled: false)).toList();

    final allowedNumbers = _approvedContacts
        .where((contact) => contact.consented)
        .map((contact) => contact.number)
        .toList();

    await prefs.setString(
      _rulesKey,
      jsonEncode(enabledRules.map((rule) => rule.toJson()).toList()),
    );

    await prefs.setString(
      _allowedNumbersKey,
      jsonEncode(allowedNumbers),
    );
  }

  Future<void> _addRule() async {
    final keyword = _keywordController.text.trim();
    final reply = _replyController.text.trim();

    if (keyword.isEmpty || reply.isEmpty) {
      _showSnack('Keyword and reply are required.');
      return;
    }

    final rule = _AutoReplyRule(
      id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
      keyword: keyword,
      reply: reply,
      enabled: true,
      cooldownMinutes: _cooldownMinutes,
    );

    setState(() {
      _rules = [rule, ..._rules];
      _status = 'Rule added and saved.';
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
      _status = 'Rule updated.';
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

  Future<void> _toggleMasterSwitch(bool enabled) async {
    setState(() {
      _autoReplyEnabled = enabled;
      _status = enabled ? 'Auto Reply enabled.' : 'Auto Reply disabled.';
    });

    await _save();
  }

  void _testRules() {
    final incoming = _testController.text.toLowerCase();
    final match = _rules.where((rule) {
      return rule.enabled &&
          rule.keyword.trim().isNotEmpty &&
          incoming.contains(rule.keyword.toLowerCase());
    }).firstOrNull;

    setState(() {
      _status = match == null
          ? 'No auto-reply rule matched the test message.'
          : 'Matched "${match.keyword}" -> ${match.reply}';
    });
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Auto Reply'),
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
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _autoReplyEnabled,
                    onChanged: _toggleMasterSwitch,
                    title: const Text(
                      'Enable Auto Reply',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '$enabledCount active rules. Replies only to approved contacts.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.person_crop_circle_badge_checkmark,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_approvedContacts.length} approved contacts can receive auto-replies.',
                          style: const TextStyle(
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Add rule'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _keywordController,
                        decoration: const InputDecoration(
                          labelText: 'Incoming keyword',
                          helperText: 'Example: yes, cancel, help',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _replyController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Auto reply',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _cooldownMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Cooldown',
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
                        icon: const Icon(CupertinoIcons.plus_circle_fill),
                        label: const Text('Add Auto Reply Rule'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Test rules'),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _testController,
                        decoration: const InputDecoration(
                          labelText: 'Test incoming message',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _testRules,
                        icon: const Icon(CupertinoIcons.lab_flask_solid),
                        label: const Text('Test Match'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Rules'),
                const SizedBox(height: 12),
                if (_rules.isEmpty)
                  const _SurfaceCard(
                    child: Text('No rules yet.'),
                  )
                else
                  ..._rules.map(
                    (rule) => _RuleCard(
                      rule: rule,
                      onToggle: () => _toggleRule(rule),
                      onDelete: () => _deleteRule(rule),
                    ),
                  ),
                const SizedBox(height: 12),
                const _PolicyCard(),
              ],
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }

    return null;
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final _AutoReplyRule rule;
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
                  'If message contains "${rule.keyword}"',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  onPressed: onToggle,
                  icon: Icon(
                    rule.enabled
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                  ),
                  label: Text(rule.enabled ? 'Disable' : 'Enable'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(CupertinoIcons.delete),
                  label: const Text('Delete'),
                ),
              ),
            ],
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
            'Automatically reply to incoming SMS keywords from approved contacts.',
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
            CupertinoIcons.shield_fill,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Auto Reply is consent-first. It only replies to approved contacts saved in Text Helper, applies cooldowns, and logs rules locally.',
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
