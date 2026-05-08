import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'automation_suite_screen.dart';
import 'backup_restore_screen.dart';
import 'background_health_wizard_screen.dart';
import 'background_service_screen.dart';
import 'battery_optimization_screen.dart';
import 'contact_groups_screen.dart';
import 'contacts_screen.dart';
import 'reliability_dashboard_screen.dart';
import 'send_history_screen.dart';
import 'visual_calendar_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Text Helper',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Text(
                'Reliable SMS reminders with groups, queueing, background checks, and backup safety.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _HomeButton(
              icon: CupertinoIcons.shield_fill,
              title: 'Reliability',
              subtitle:
                  'Check permissions, duplicate risk, failures, and background readiness.',
              onTap: () => _open(context, const ReliabilityDashboardScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.battery_25,
              title: 'Battery Optimization',
              subtitle:
                  'Review battery restrictions that can delay or stop background sends.',
              onTap: () => _open(context, const BatteryOptimizationScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.list_bullet_indent,
              title: 'Background Wizard',
              subtitle:
                  'Step through SMS permission, alarm setup, test queueing, and sync.',
              onTap: () => _open(context, const BackgroundHealthWizardScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.gear_alt_fill,
              title: 'Automation',
              subtitle: 'Schedule, queue, and send reminder texts.',
              onTap: () => _open(context, const AutomationSuiteScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.person_3_fill,
              title: 'Contact Groups',
              subtitle: 'Create groups, assign contacts, and queue group texts.',
              onTap: () => _open(context, const ContactGroupsScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.archivebox_fill,
              title: 'Backup & Restore',
              subtitle:
                  'Export and restore contacts, reminders, queue data, and logs.',
              onTap: () => _open(context, const BackupRestoreScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.calendar,
              title: 'Visual Calendar',
              subtitle: 'See appointments by month and add reminders.',
              onTap: () => _open(context, const VisualCalendarScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.clock_fill,
              title: 'Background Scheduler',
              subtitle: 'Sync queued texts to send when app is closed.',
              onTap: () => _open(context, const BackgroundServiceScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.doc_text_search,
              title: 'Send History',
              subtitle: 'View sent, failed, blocked, and retryable sends.',
              onTap: () => _open(context, const SendHistoryScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.person_2_fill,
              title: 'Contacts',
              subtitle: 'Add or edit NZ test numbers.',
              onTap: () => _open(context, const ContactsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
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
