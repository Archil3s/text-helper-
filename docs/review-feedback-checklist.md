# Review feedback implementation checklist

This checklist tracks the major complaints found in competing SMS scheduler reviews and what Text Helper has or still needs.

## Added / foundation complete

- [x] Reliability dashboard
  - Health score
  - Queue summary
  - Duplicate scan
  - Failure/blocked/sent counts
  - Debug report export

- [x] Duplicate protection foundation
  - Blocks already-sent reminder IDs
  - Blocks same phone number + same message within 24 hours
  - Logs blocked duplicate sends

- [x] Background scheduler foundation
  - Android AlarmManager path
  - BroadcastReceiver path
  - Native SMS sender path
  - Background alarm sync/cancel service

- [x] Background setup checklist foundation
  - SMS permission check
  - Exact alarm permission check
  - Queued text check
  - Test number check

- [x] Send history / audit log foundation
  - Sent logs
  - Failed logs
  - Blocked logs
  - Error message storage

- [x] Contact groups foundation
  - Test Numbers
  - Clients
  - Appointments
  - Do Not Send group model

- [x] Rate limit foundation
  - 3 sends per minute cap
  - 30 sends per hour cap
  - 100 sends per day cap
  - Blocked rate-limit log helper

- [x] Backup export foundation
  - Recipients export
  - Reminders export
  - Send logs export
  - JSON clipboard export service

- [x] Privacy cleanup target
  - Reminder/log base models should not persist contact names
  - Names should live in the contacts model/store only

## Still to build / wire into product

- [x] Wire rate-limit checks into every send path
  - Automation send-now path
  - Queue runner path
  - Native background receiver path
  - Rate-limit checks now run before SMS send attempts
  - Automation send-now and queue runner use RateLimitService
  - Native background receiver blocks sends above rate caps

- [x] Add Retry Failed Sends
  - Retry individual failed messages
  - Retry all failed messages
  - Preserve duplicate/rate-limit safety checks
  - Retry individual failed sends from Send History
  - Retry all failed sends from Send History
  - Retry preserves Test Mode, duplicate protection, and rate-limit checks

- [x] Add Backup Restore screen
  - Export backup
  - Paste/import backup JSON
  - Validate backup version
  - Restore contacts/reminders/logs safely
  - Backup Restore screen added to Home
  - Export copies backup JSON to clipboard
  - Restore from clipboard or pasted JSON
  - Backup version validation added
  - Restore supports contacts, reminders, and optional send logs

- [x] Add Contact Groups UI
  - Create/edit/delete groups
  - Add/remove contacts from groups
  - Queue messages by group
  - Contact Groups screen added to Home
  - Create/edit/delete groups
  - Add/remove contacts from groups
  - Queue one message to every contact in a group

- [x] Enforce Do Not Send hard block
  - Check group membership before sending
  - Log blocked sends clearly
  - Automation blocks Do Not Send contacts before sending
  - Retry blocks Do Not Send contacts before sending
  - Background Scheduler filters Do Not Send contacts before alarm sync
  - Native background receiver checks Do Not Send groups before sending
  - Blocked sends are logged clearly

- [x] Add Background Health Wizard UI
  - Step 1: SMS permission
  - Step 2: Exact alarm permission
  - Step 3: Battery optimization warning
  - Step 4: Queue a test text
  - Step 5: Sync background alarms
  - Background Wizard screen added to Home
  - SMS permission step added
  - Exact alarm settings step added
  - Battery warning review step added
  - Queue test text step added
  - Sync background alarms step added

- [x] Add Battery Optimization warning
  - Explain that some phones delay/kill background alarms
  - Give user setup guidance
  - Battery Optimization screen added to Home
  - Native Android battery optimization status check added
  - Android battery optimization settings button added
  - User warning and reviewed state added
  - Guidance for force-stop and manufacturer battery managers added

- [x] Add per-message status timeline
  - Queued
  - Background alarm synced
  - Triggered
  - Sent to Android SMS service
  - Failed
  - Blocked
  - Message Timeline screen added to Home
  - Timeline event model/store/service added
  - Queued, synced, triggered, sent, failed, and blocked states shown
  - Background alarm sync writes timeline events
  - Timeline derives status from reminders and send logs

- [x] Add CSV import/export
  - Import contacts/appointments
  - Export reminders/logs
  - CSV Import / Export screen added to Home
  - Import contacts from clipboard or pasted CSV
  - Import reminders/appointments from clipboard or pasted CSV
  - Export contacts, reminders, and send logs as CSV
  - Merge or replace import mode added

- [x] Add Template Manager
  - Create/edit/delete templates
  - Placeholder support: {name}, {date}, {time}, {location}, {appointment}
  - Template Manager screen added to Home
  - Create/edit/delete custom templates
  - Duplicate built-in templates
  - Copy templates to clipboard
  - Placeholder preview added for {name}, {date}, {time}, {location}, and {appointment}

- [x] Add delivery receipt support if feasible
  - Keep wording as "Sent to Android SMS service" until real carrier delivery receipts are implemented
  - Native sent PendingIntent receiver added
  - Native delivered PendingIntent receiver added
  - Delivery Receipts screen added to Home
  - Native receipt events are stored for Flutter UI
  - App keeps wording as "Sent to Android SMS service" unless real delivery callback is received

- [x] Add clear SMS-only/MMS policy
  - Avoid users expecting images/video/MMS unless intentionally implemented
  - SMS / MMS Policy screen added to Home
  - App clearly states SMS text only
  - App clearly states MMS/media/images/videos/files are not supported yet
  - Delivery wording guidance included
  - Policy reviewed state added

## Ranked post-release complaint backlog

These are ranked by review frequency, trust impact, and risk of users uninstalling or requesting refunds.

1. - [ ] Add Support Center and refund/help route
   - In-app support screen with email/support link
   - Copyable diagnostic summary
   - Refund guidance for paid users
   - Clear route for bug reports, screenshots, and test evidence
   - Addresses repeated complaints about no response from support and no clear refund path

2. - [ ] Add Permissions and Privacy explanation screen
   - Explain why SMS permission is needed
   - Explain background alarm/battery permissions
   - Explain what data stays local
   - Explain that contact names are stored only in contacts
   - Explain why antivirus apps may warn about SMS/background capability

3. - [ ] Add brand-specific background setup guides
   - Samsung guide
   - Xiaomi/Redmi/POCO guide
   - Oppo/Realme/OnePlus guide
   - Vivo guide
   - Huawei/Honor guide
   - Include battery optimization, auto-start, sleeping apps, app launch, and lock-screen behavior

4. - [ ] Add recipient confirmation and send audit preview
   - Preview every recipient before queueing/sending
   - Show contact name, phone number, group, test/live state, and final message
   - Warn about empty or suspicious phone numbers
   - Warn about country-code normalization changes
   - Reduce wrong-recipient, wrong-group, and random-contact complaints

5. - [ ] Add schedule validation and advanced repeat builder
   - Validate final scheduled date/time before saving
   - Show next 5 occurrences for recurring messages
   - Add custom interval builder
   - Add time-range window support
   - Add 12-hour/24-hour display preference
   - Warn when selected time is in the past or shifted by device settings

6. - [ ] Add notification sound and reminder channel test
   - Test reminder notification channel
   - Test notification sound/vibration
   - Link to Android notification settings
   - Show whether notifications are blocked
   - Address complaints about reminder sound or popups stopping after updates

7. - [ ] Add purchase restore and pricing clarity screen
   - Restore purchase entry point
   - Clear free vs paid capability table
   - Trial status explanation
   - Subscription cancellation guidance
   - No-ads/paid-status diagnostics if billing is later added

8. - [ ] Add crash, freeze, and diagnostics export bundle
   - Export device/app diagnostic report
   - Include Android version, manufacturer, battery status, permission status, queue count, failed logs, and background health
   - Add one-tap copy for support
   - Add local crash/failure notes for lag/freeze reports

9. - [ ] Add RCS and WhatsApp expectation policy or roadmap
   - Clearly state SMS support boundaries
   - Clearly state RCS is not controlled by this app unless explicitly implemented
   - Clearly state WhatsApp automation is not currently part of SMS scheduling
   - Prevent false expectation from users looking for WhatsApp/RCS auto-replies

10. - [ ] Add bulk-send safety and large import limits
   - Select-all contacts/group tooling
   - Batch progress UI
   - Estimated duration before sending
   - Rate-limit preview before queueing
   - Large CSV import warnings
   - Guardrails for hundreds/thousands of recipients

11. - [ ] Add update-safe migration checks
   - Versioned local data migrations
   - Pre-update backup reminder
   - Detect empty data after app version changes
   - Restore prompts if reminders or contacts disappear unexpectedly
   - Prevent scheduled reminders being wiped after updates

12. - [ ] Add ads/no-ads product policy
   - State whether the app has ads or is ad-free
   - If ads are ever added, avoid full-screen blocking ads during critical scheduling flows
   - Never show ads over send/queue confirmation screens
   - Avoid loud/video ads in appointment/reminder workflows

## Release gate

Before release/android-beta-v1:

- [ ] flutter analyze passes
- [ ] flutter build apk --debug passes
- [ ] Real Android phone test passes
- [ ] Background closed-app test passes
- [ ] Duplicate-send test passes
- [ ] Do Not Send block test passes
- [ ] Backup export/import test passes
