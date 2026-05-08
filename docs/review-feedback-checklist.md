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

- [ ] Wire rate-limit checks into every send path
  - Automation send-now path
  - Queue runner path
  - Native background receiver path

- [ ] Add Retry Failed Sends
  - Retry individual failed messages
  - Retry all failed messages
  - Preserve duplicate/rate-limit safety checks

- [ ] Add Backup Restore screen
  - Export backup
  - Paste/import backup JSON
  - Validate backup version
  - Restore contacts/reminders/logs safely

- [ ] Add Contact Groups UI
  - Create/edit/delete groups
  - Add/remove contacts from groups
  - Queue messages by group

- [ ] Enforce Do Not Send hard block
  - Check group membership before sending
  - Log blocked sends clearly

- [ ] Add Background Health Wizard UI
  - Step 1: SMS permission
  - Step 2: Exact alarm permission
  - Step 3: Battery optimization warning
  - Step 4: Queue a test text
  - Step 5: Sync background alarms

- [ ] Add Battery Optimization warning
  - Explain that some phones delay/kill background alarms
  - Give user setup guidance

- [ ] Add per-message status timeline
  - Queued
  - Background alarm synced
  - Triggered
  - Sent to Android SMS service
  - Failed
  - Blocked

- [ ] Add CSV import/export
  - Import contacts/appointments
  - Export reminders/logs

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
