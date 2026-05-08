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

- [ ] Add Template Manager
  - Create/edit/delete templates
  - Placeholder support: {name}, {date}, {time}, {location}, {appointment}

- [ ] Add delivery receipt support if feasible
  - Keep wording as "Sent to Android SMS service" until real carrier delivery receipts are implemented

- [ ] Add clear SMS-only/MMS policy
  - Avoid users expecting images/video/MMS unless intentionally implemented

## Release gate

Before release/android-beta-v1:

- [ ] flutter analyze passes
- [ ] flutter build apk --debug passes
- [ ] Real Android phone test passes
- [ ] Background closed-app test passes
- [ ] Duplicate-send test passes
- [ ] Do Not Send block test passes
- [ ] Backup export/import test passes









