import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupportTriageCenterScreen extends StatefulWidget {
  const SupportTriageCenterScreen({super.key});

  @override
  State<SupportTriageCenterScreen> createState() =>
      _SupportTriageCenterScreenState();
}

class _SupportTriageCenterScreenState extends State<SupportTriageCenterScreen> {
  final List<_SupportCase> _cases = const <_SupportCase>[
    _SupportCase(
      title: 'Message did not send',
      priority: 'Critical',
      category: 'Delivery',
      summary:
          'User expected a scheduled SMS to send, but it did not send or there is no clear send result.',
      firstReply:
          'Thanks for reporting this. Please keep the app installed while we review the send path. Open Send History and Message Timeline, then copy the latest failed or missing send details. Also confirm whether battery optimization is disabled for Text Helper.',
      evidence:
          'Send History entry, Message Timeline entry, scheduled time, phone model, Android version, battery setting, and whether the phone was locked.',
      nextAction:
          'Check background permission, exact alarm access, battery restriction, queue state, and sent callback state.',
    ),
    _SupportCase(
      title: 'Duplicate message sent',
      priority: 'Critical',
      category: 'Safety',
      summary:
          'User received or sent the same text more than once after retry, reopen, or background sync.',
      firstReply:
          'Thanks for reporting this. Please do not delete the send history yet. Copy the Send History entry and Message Timeline for the affected recipient so we can confirm whether this was a retry loop or duplicate queue item.',
      evidence:
          'Recipient, scheduled time, duplicate send times, retry count, queue id if visible, and timeline entries.',
      nextAction:
          'Verify duplicate protection, idempotent send id, retry backoff, and queue cleanup after sent callback.',
    ),
    _SupportCase(
      title: 'Battery or background issue',
      priority: 'High',
      category: 'Device setup',
      summary:
          'Android killed background work, delayed scheduled sends, or blocked the scheduler while the app was closed.',
      firstReply:
          'This is usually caused by Android battery restrictions. Open Battery Optimization and Device Setup Guides in Text Helper, then apply the steps for your phone brand. After that, run Background Wizard and send one test reminder.',
      evidence:
          'Phone brand, Android version, battery optimization state, background permission state, and Background Wizard result.',
      nextAction:
          'Guide the user through battery exception, exact alarm access, notification permission, and background scheduler test.',
    ),
    _SupportCase(
      title: 'Feature missing after update',
      priority: 'Critical',
      category: 'Regression',
      summary:
          'User says SMS scheduling, reminders, send history, backup, or another core screen disappeared after update.',
      firstReply:
          'Thanks for reporting this regression. Please open Core Regression Checks and tell us which item is missing. If a screen disappeared after update, we will block release until the route is restored.',
      evidence:
          'App version, missing screen name, route previously used, screenshot of Home, and update date.',
      nextAction:
          'Run Core Regression Checks and verify Home route, import, screen class, and release checklist coverage.',
    ),
    _SupportCase(
      title: 'Backup or restore failed',
      priority: 'High',
      category: 'Data safety',
      summary:
          'User lost scheduled messages, contacts, templates, history, or restore did not bring data back.',
      firstReply:
          'Please do not reinstall again yet. Open Backup and Restore, copy the backup summary, and confirm whether the backup was created before or after the app update.',
      evidence:
          'Backup date, restore date, app version before update, app version after update, and which data type is missing.',
      nextAction:
          'Check backup schema version, restore validation, migration logs, and whether seed data overwrote user data.',
    ),
    _SupportCase(
      title: 'Permissions or security concern',
      priority: 'High',
      category: 'Trust',
      summary:
          'User is worried about SMS, contacts, phone, notification, or background permissions.',
      firstReply:
          'Text Helper uses permissions only for local SMS reminder workflows and local app features. Open Permissions and Privacy for the current explanation. Tell us which permission caused concern so we can clarify or reduce it.',
      evidence:
          'Permission name, Android prompt text, phone model, Android version, and screen where prompt appeared.',
      nextAction:
          'Check whether the permission is required, optional, overbroad, or can be delayed until feature use.',
    ),
    _SupportCase(
      title: 'Delivery status confusion',
      priority: 'Medium',
      category: 'Receipts',
      summary:
          'User thinks Sent means carrier delivered the message, or delivery receipt did not arrive.',
      firstReply:
          'Text Helper should only say Delivered when Android provides a delivery receipt. If the app says Sent, that means the message was handed to the Android SMS service.',
      evidence:
          'Send History status, Delivery Receipts entry, carrier, recipient network, and whether delivery reports are enabled.',
      nextAction:
          'Check sent callback versus delivery callback and ensure labels do not overclaim delivery.',
    ),
    _SupportCase(
      title: 'Refund or billing request',
      priority: 'Medium',
      category: 'Billing redirect',
      summary:
          'User asks for refund, charge reversal, trial issue, or purchase restore help.',
      firstReply:
          'For store billing, refunds, and receipt issues, use the app store purchase channel first because payment processing is handled by the store. We can still help with technical logs if a feature did not work as expected.',
      evidence:
          'Store receipt date, order id if the user wants to provide it, app version, and technical issue summary.',
      nextAction:
          'Route billing to the store process and keep technical investigation separate from payment handling.',
    ),
  ];

  int _selectedIndex = 0;
  String _status = 'Select an issue type to copy a support response.';

  _SupportCase get _selectedCase => _cases[_selectedIndex];

  int get _criticalCount {
    return _cases.where((item) => item.priority == 'Critical').length;
  }

  int get _highCount {
    return _cases.where((item) => item.priority == 'High').length;
  }

  Future<void> _copySelectedReply() async {
    final item = _selectedCase;
    final buffer = StringBuffer();

    buffer.writeln('Support reply: ${item.title}');
    buffer.writeln('');
    buffer.writeln(item.firstReply);
    buffer.writeln('');
    buffer.writeln('Evidence needed:');
    buffer.writeln(item.evidence);
    buffer.writeln('');
    buffer.writeln('Internal next action:');
    buffer.writeln(item.nextAction);

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Support reply copied for ${item.title}.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support reply copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyTriageReport() async {
    final buffer = StringBuffer();

    buffer.writeln('Text Helper support triage report');
    buffer.writeln('Case count: ${_cases.length}');
    buffer.writeln('Critical: $_criticalCount');
    buffer.writeln('High: $_highCount');
    buffer.writeln('');

    for (final item in _cases) {
      buffer.writeln('${item.priority} - ${item.category} - ${item.title}');
      buffer.writeln(item.summary);
      buffer.writeln('Evidence: ${item.evidence}');
      buffer.writeln('Next action: ${item.nextAction}');
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Full support triage report copied.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support triage report copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyAutoReplyTemplate() async {
    const text = '''
Thanks for contacting Text Helper support.

Please reply with:

1. Phone model.
2. Android version.
3. App version.
4. What you expected to happen.
5. What actually happened.
6. Whether the phone was locked at the scheduled time.
7. Whether battery optimization is disabled for Text Helper.
8. A copied Send History or Message Timeline entry if this is about a message.

Please do not uninstall yet if the issue involves missing data, send history, or backup restore.
''';

    await Clipboard.setData(const ClipboardData(text: text));

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'General auto-reply template copied.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-reply template copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectCase(int index) {
    setState(() {
      _selectedIndex = index;
      _status = '${_cases[index].title} selected.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedCase;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Support Triage Center'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _copyTriageReport,
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroCard(
            total: _cases.length,
            critical: _criticalCount,
            high: _highCount,
          ),
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: Color(0xFF0A84FF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _copySelectedReply,
                  icon: const Icon(CupertinoIcons.chat_bubble_text_fill),
                  label: const Text('Copy reply'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyAutoReplyTemplate,
                  icon: const Icon(CupertinoIcons.mail_solid),
                  label: const Text('Auto-reply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Selected case',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          _SelectedCaseCard(item: item),
          const SizedBox(height: 24),
          const Text(
            'Issue types',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _cases.length,
            (index) => _CaseButton(
              item: _cases[index],
              selected: index == _selectedIndex,
              onTap: () => _selectCase(index),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _copyTriageReport,
            icon: const Icon(CupertinoIcons.doc_text_fill),
            label: const Text('Copy full triage report'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.total,
    required this.critical,
    required this.high,
  });

  final int total;
  final int critical;
  final int high;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.headphones,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Support triage',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copy structured support replies, evidence requests, and escalation notes for common customer issues.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Metric(value: '$total', label: 'cases'),
              const SizedBox(width: 10),
              _Metric(value: '$critical', label: 'critical'),
              const SizedBox(width: 10),
              _Metric(value: '$high', label: 'high'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCaseCard extends StatelessWidget {
  const _SelectedCaseCard({
    required this.item,
  });

  final _SupportCase item;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Badge(
                text: item.priority,
                color: item.priority == 'Critical'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF97316),
              ),
              _Badge(
                text: item.category,
                color: const Color(0xFF0A84FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.summary,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _InfoBlock(title: 'First reply', text: item.firstReply),
          _InfoBlock(title: 'Evidence needed', text: item.evidence),
          _InfoBlock(title: 'Next action', text: item.nextAction),
        ],
      ),
    );
  }
}

class _CaseButton extends StatelessWidget {
  const _CaseButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SupportCase item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? const Color(0xFF0A84FF) : Colors.transparent;

    return _SurfaceCard(
      borderColor: borderColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? const Color(0xFF0A84FF)
                  : CupertinoColors.secondaryLabel,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.priority} - ${item.category}',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0A84FF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SupportCase {
  const _SupportCase({
    required this.title,
    required this.priority,
    required this.category,
    required this.summary,
    required this.firstReply,
    required this.evidence,
    required this.nextAction,
  });

  final String title;
  final String priority;
  final String category;
  final String summary;
  final String firstReply;
  final String evidence;
  final String nextAction;
}
