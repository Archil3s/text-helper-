# Text Helper — Reliable SMS Reminder Automation

Development branch: `dev/sms-automation-v1`

Review-driven checklist: [docs/review-feedback-checklist.md](docs/review-feedback-checklist.md)

## Current focus

Text Helper is being built around the main complaints from SMS scheduler reviews:

- reliable background sending
- duplicate-send protection
- clear send history and failure logs
- backup/export safety
- contact groups and Do Not Send controls
- background permission health checks

## Implementation status

| Area | Status |
|---|---:|
| Reliability dashboard | ✅ Added |
| Duplicate-send protection | ✅ Added |
| Background scheduler foundation | ✅ Added |
| Background health wizard UI | ✅ Added |
| Send history and retry failed sends | ✅ Added |
| Backup export and restore screen | ✅ Added |
| Contact groups UI | ✅ Added |
| Do Not Send hard block | ✅ Added |
| Rate-limit checks in send paths | ✅ Added |
| Privacy cleanup for reminder/log base models | ✅ Added |
| Battery optimization warning | ⏳ Next |
| Per-message status timeline | ⏳ Pending |
| CSV import/export | ⏳ Pending |
| Template manager | ⏳ Pending |
| Delivery receipt support | ⏳ Pending / feasible check needed |
| Clear SMS-only/MMS policy | ⏳ Pending |
| Release gate testing | ⏳ Pending |

## Completed review-feedback fixes

- Reliability dashboard with health score, queue summary, duplicate scan, and debug report export
- Duplicate protection for already-sent reminder IDs and same phone/message within 24 hours
- Background scheduler foundation using Android AlarmManager/BroadcastReceiver/native SMS sender
- Background health wizard for SMS permission, exact alarm setup, battery warning review, test queueing, and sync
- Send history with sent, failed, blocked, and retryable logs
- Retry failed sends with Test Mode, duplicate protection, and rate-limit checks preserved
- Backup and restore screen with JSON export, clipboard restore, pasted JSON restore, and version validation
- Contact groups screen with create/edit/delete, contact assignment, and group queueing
- Do Not Send hard block before Automation sends, retries, background sync, and native background sending
- Rate-limit foundation and enforcement before SMS send attempts

## Still pending

- Battery optimization warning and guidance screen
- Per-message status timeline: queued → synced → triggered → sent/failed/blocked
- CSV import/export for contacts, appointments, reminders, and logs
- Template manager with placeholders: `{name}`, `{date}`, `{time}`, `{location}`, `{appointment}`
- Delivery receipt support if feasible; until then, use “Sent to Android SMS service,” not “Delivered”
- Clear SMS-only/MMS policy so users do not expect images/video/MMS
- Release gate testing on a real Android phone

See the full checklist for detailed status:

[Review feedback implementation checklist](docs/review-feedback-checklist.md)
