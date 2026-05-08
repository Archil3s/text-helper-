# Text Helper â€” Reliable SMS Reminder Automation

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
| Reliability dashboard | âœ… Added |
| Duplicate-send protection | âœ… Added |
| Background scheduler foundation | âœ… Added |
| Background health wizard UI | âœ… Added |
| Send history and retry failed sends | âœ… Added |
| Backup export and restore screen | âœ… Added |
| Contact groups UI | âœ… Added |
| Do Not Send hard block | âœ… Added |
| Rate-limit checks in send paths | âœ… Added |
| Privacy cleanup for reminder/log base models | âœ… Added |
| Battery optimization warning | â³ Next |
| Per-message status timeline | â³ Pending |
| CSV import/export | â³ Pending |
| Template manager | â³ Pending |
| Delivery receipt support | â³ Pending / feasible check needed |
| Clear SMS-only/MMS policy | â³ Pending |
| Release gate testing | â³ Pending |

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

- Battery optimization warning screen with native Android status check and setup guidance

- Per-message timeline for queued, synced, triggered, sent, failed, and blocked states

- Template manager with reusable messages and placeholders

## Still pending

- Battery optimization warning and guidance screen
- Per-message status timeline: queued â†’ synced â†’ triggered â†’ sent/failed/blocked
- CSV import/export for contacts, appointments, reminders, and logs
- Template manager with placeholders: `{name}`, `{date}`, `{time}`, `{location}`, `{appointment}`
- Delivery receipt support if feasible; until then, use â€œSent to Android SMS service,â€ not â€œDeliveredâ€
- Clear SMS-only/MMS policy so users do not expect images/video/MMS
- Release gate testing on a real Android phone

See the full checklist for detailed status:

[Review feedback implementation checklist](docs/review-feedback-checklist.md)




