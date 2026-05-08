import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ScheduledSmsScreen extends StatefulWidget {
  const ScheduledSmsScreen({super.key});

  @override
  State<ScheduledSmsScreen> createState() => _ScheduledSmsScreenState();
}

class _ScheduledSmsScreenState extends State<ScheduledSmsScreen> {
  final TextEditingController _controller = TextEditingController(
    text: 'Quick reminder: please confirm when you get this.',
  );

  String _selectedGroup = 'Family';
  String _selectedDate = 'Today';
  String _selectedTime = '6:30 PM';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved locally. Real SMS sending is disabled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cycleGroup() {
    setState(() {
      _selectedGroup = switch (_selectedGroup) {
        'Family' => 'Work',
        'Work' => 'Test Send',
        _ => 'Family',
      };
    });
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
    final scheduledLabel = '$_selectedDate • $_selectedTime';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Scheduled SMS'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(
            title: 'Scheduled SMS',
            subtitle: 'Draft for $_selectedGroup at $scheduledLabel.',
            icon: CupertinoIcons.calendar_badge_plus,
          ),
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              children: [
                _PickerRow(label: 'Group', value: _selectedGroup, onTap: _cycleGroup),
                const Divider(height: 24),
                _PickerRow(label: 'Date', value: _selectedDate, onTap: _cycleDate),
                const Divider(height: 24),
                _PickerRow(label: 'Time', value: _selectedTime, onTap: _cycleTime),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
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
                  onPressed: _saveDraft,
                  icon: const Icon(CupertinoIcons.tray_arrow_down_fill),
                  label: const Text('Save local draft'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
