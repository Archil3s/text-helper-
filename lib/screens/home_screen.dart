import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'automation_suite_screen.dart';
import 'backup_restore_screen.dart';
import 'background_health_wizard_screen.dart';
import 'background_service_screen.dart';
import 'battery_optimization_screen.dart';
import 'brand_background_guides_screen.dart';
import 'bulk_send_safety_screen.dart';
import 'contact_groups_screen.dart';
import 'contacts_screen.dart';
import 'crash_diagnostics_screen.dart';
import 'csv_import_export_screen.dart';
import 'delivery_receipts_screen.dart';
import 'message_timeline_screen.dart';
import 'notification_channel_test_screen.dart';
import 'permissions_privacy_screen.dart';
import 'rcs_whatsapp_policy_screen.dart';
import 'recipient_audit_preview_screen.dart';
import 'reliability_dashboard_screen.dart';
import 'schedule_validation_screen.dart';
import 'send_history_screen.dart';
import 'sms_policy_screen.dart';
import 'template_manager_screen.dart';
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
                'Reliable SMS text reminders with recipient audit, schedule validation, privacy guidance, device setup, notification tests, diagnostics, bulk-send safety, receipts, templates, timeline, CSV tools, groups, queueing, background checks, and backup safety.',
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
              icon: CupertinoIcons.person_crop_circle_badge_checkmark,
              title: 'Recipient Audit',
              subtitle:
                  'Preview every queued recipient, final message, phone warning, and test/live state.',
              onTap: () => _open(context, const RecipientAuditPreviewScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.calendar_badge_plus,
              title: 'Schedule Builder',
              subtitle:
                  'Validate date/time, recurrence, custom intervals, and sending windows.',
              onTap: () => _open(context, const ScheduleValidationScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.bell_circle_fill,
              title: 'Notification Sound Test',
              subtitle:
                  'Test reminder notification sound, vibration, permission, and channel settings.',
              onTap: () =>
                  _open(context, const NotificationChannelTestScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.wrench_fill,
              title: 'Crash Diagnostics',
              subtitle:
                  'Copy device, permission, queue, failure, and background health diagnostics.',
              onTap: () => _open(context, const CrashDiagnosticsScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.chat_bubble_2_fill,
              title: 'RCS & WhatsApp Policy',
              subtitle:
                  'Clarify that automation is SMS-only and does not send RCS or WhatsApp.',
              onTap: () => _open(context, const RcsWhatsAppPolicyScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.exclamationmark_shield_fill,
              title: 'Bulk Send Safety',
              subtitle:
                  'Preview batch size, rate limits, warnings, and large import guardrails.',
              onTap: () => _open(context, const BulkSendSafetyScreen()),
            ),
            _HomeButton(
              icon: Icons.privacy_tip_outlined,
              title: 'Permissions & Privacy',
              subtitle:
                  'Explain SMS permission, background alarms, local data, and antivirus warnings.',
              onTap: () => _open(context, const PermissionsPrivacyScreen()),
            ),
            _HomeButton(
              icon: Icons.phone_android_outlined,
              title: 'Device Setup Guides',
              subtitle:
                  'Samsung, Xiaomi, Oppo, Realme, OnePlus, Vivo, Huawei, and Honor setup tips.',
              onTap: () => _open(context, const BrandBackgroundGuidesScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.chat_bubble_text_fill,
              title: 'SMS / MMS Policy',
              subtitle:
                  'Clarifies that Text Helper sends SMS text only, not MMS/media.',
              onTap: () => _open(context, const SmsPolicyScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.check_mark_circled_solid,
              title: 'Delivery Receipts',
              subtitle:
                  'Track sent callbacks and carrier delivery callbacks when available.',
              onTap: () => _open(context, const DeliveryReceiptsScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.text_bubble_fill,
              title: 'Template Manager',
              subtitle:
                  'Create, edit, copy, and preview message templates with placeholders.',
              onTap: () => _open(context, const TemplateManagerScreen()),
            ),
            _HomeButton(
              icon: CupertinoIcons.list_bullet,
              title: 'Message Timeline',
              subtitle:
                  'Track queued, synced, triggered, sent, failed, and blocked events.',
              onTap: () => _open(context, const MessageTimelineScreen()),
            ),
            _HomeButton(
              icon: Icons.table_chart_outlined,
              title: 'CSV Import / Export',
              subtitle:
                  'Import contacts and reminders, or export contacts, reminders, and logs.',
              onTap: () => _open(context, const CsvImportExportScreen()),
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
              subtitle:
                  'Create groups, assign contacts, and queue group texts.',
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
