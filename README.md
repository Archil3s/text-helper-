# Text Helper ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Reliable SMS Reminder Automation

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
| Reliability dashboard | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Duplicate-send protection | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Background scheduler foundation | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Background health wizard UI | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Send history and retry failed sends | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Backup export and restore screen | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Contact groups UI | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Do Not Send hard block | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Rate-limit checks in send paths | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Privacy cleanup for reminder/log base models | ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Added |
| Battery optimization warning | ÃƒÂ¢Ã‚ÂÃ‚Â³ Next |
| Per-message status timeline | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending |
| CSV import/export | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending |
| Template manager | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending |
| Delivery receipt support | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending / feasible check needed |
| Clear SMS-only/MMS policy | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending |
| Release gate testing | ÃƒÂ¢Ã‚ÂÃ‚Â³ Pending |

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

- Delivery receipt support using Android sent/delivered callbacks where carrier/device supports it


## SMS-only / MMS policy

Text Helper currently sends SMS text messages only.

Supported:

- Plain SMS text reminders
- Appointment reminders
- Follow-up texts
- Confirmation texts
- Scheduled text-only messages

Not supported yet:

- MMS
- Images
- Videos
- Audio files
- PDFs
- Contact cards
- GIFs, stickers, or other media attachments

The app should use Ã¢â‚¬Å“Sent to Android SMS serviceÃ¢â‚¬Â unless a real carrier/device delivery callback is received. It should not claim Ã¢â‚¬Å“DeliveredÃ¢â‚¬Â unless Android provides a delivery receipt.

- SMS-only policy screen clarifying that MMS/media is not supported yet
- RCS & WhatsApp Policy screen clarifying SMS-only automation, unsupported RCS/WhatsApp/MMS/media behavior, and safe delivery wording
- Bulk Send Safety screen with consented contact counts, test/live split, rate-limit preview, duration estimate, warning preview, and large-batch guidance


## Permissions and Privacy explanation

Text Helper includes an in-app Permissions & Privacy screen explaining:

- why SMS permission is needed
- why exact alarm/background scheduling permissions are needed
- why battery optimization settings affect closed-app sending
- what data stays local on the device
- that contact names are stored in the contacts model/store only
- why antivirus tools may warn about apps that can send SMS or run background alarms

## Brand-specific background setup guides

Text Helper includes device setup guides for:

- Samsung / Galaxy
- Xiaomi / Redmi / POCO
- Oppo / Realme / OnePlus
- Vivo / iQOO
- Huawei / Honor

The guides cover battery optimization, auto-start, sleeping apps, app launch management, background activity, notifications, lock-screen behavior, and closed-app testing.


## Recipient Audit Preview

Text Helper includes a Recipient Audit screen to reduce wrong-recipient, wrong-group, and random-contact mistakes. It previews every queued recipient before sending or background sync, including:

- contact name
- phone number
- normalized phone number
- group label
- test/live state
- scheduled time
- final message text
- warnings for empty or suspicious numbers
- warnings when country-code normalization would change the number

## Schedule Validation and Advanced Repeat Builder

Text Helper includes a Schedule Builder to validate date/time and recurrence choices before saving reminders. It supports:

- first-run date/time validation
- next 5 occurrence preview
- once, every-minute test, hourly, daily, weekly, monthly, and custom interval rules
- custom interval units: minutes, hours, days, and weeks
- sending window start/end times
- 12-hour or 24-hour display preference
- warnings for past times, risky monthly dates, and sending-window conflicts

## Still pending

- Battery optimization warning and guidance screen
- Per-message status timeline: queued ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ synced ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ triggered ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ sent/failed/blocked
- CSV import/export for contacts, appointments, reminders, and logs
- Template manager with placeholders: `{name}`, `{date}`, `{time}`, `{location}`, `{appointment}`
- Delivery receipt support if feasible; until then, use ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œSent to Android SMS service,ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â not ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œDeliveredÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
- Clear SMS-only/MMS policy so users do not expect images/video/MMS
- Release gate testing on a real Android phone

See the full checklist for detailed status:

[Review feedback implementation checklist](docs/review-feedback-checklist.md)

## Local APK build workflow

Every local feature script should build a fresh debug APK before commit or push.

Use this command from the project root:

    .\scripts\build-copy-apk.ps1

The build script:

- reads the app version from pubspec.yaml
- prints app version, build number, branch, and commit
- deletes old APKs from dist\localsend
- runs dart format lib
- runs flutter analyze
- runs flutter build apk --debug
- copies one versioned APK to dist\localsend
- leaves only one APK to send with LocalSend

Copy/send the file printed after:

    COPY THIS APK:

## Constant Android revision install workflow

Every local revision should use:

    .\scripts\build-copy-apk.ps1

That script builds a fresh debug APK, writes this constant copy:

    dist\localsend\TextHelper-COPY-THIS.apk

Then it pushes the APK to the connected Galaxy A16 Download folder:

    /sdcard/Download/TextHelper-COPY-THIS.apk

On Windows this appears as:

    This PC\Galaxy A16\Internal storage\Download\TextHelper-COPY-THIS.apk

It then installs/updates the app and launches it automatically through ADB.

Requirements:

- USB debugging enabled on the phone
- phone authorized in adb devices
- adb.exe available in PATH or Android SDK platform-tools
