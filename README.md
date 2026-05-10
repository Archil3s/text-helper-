# Text Helper

Text Helper is a Flutter Android app for reliable SMS reminder workflows.

## Current focus

Text Helper focuses on:

- Reliable background sending.
- Duplicate-send protection.
- Clear send history and failure logs.
- Backup and restore safety.
- Contact groups and Do Not Send controls.
- Background permission health checks.
- SMS-only reminder automation.

## Implementation checklist

This checklist tracks what is done, what is partly done, and what should be finished next. Update the boxes as each item is built, tested on a real Android phone, and pushed to main.

### Done or currently present

- [x] Flutter Android project builds a debug APK.
- [x] Home menu restored with the main feature screens.
- [x] Contacts screen exists for test numbers.
- [x] Automation screen exists for scheduling and queue workflows.
- [x] Background Scheduler screen exists.
- [x] Background Wizard screen exists.
- [x] Visual Calendar screen exists.
- [x] Schedule Builder screen exists.
- [x] Recipient Audit screen exists.
- [x] Bulk Send Safety screen exists.
- [x] Send History screen exists.
- [x] Message Timeline screen exists.
- [x] Delivery Receipts screen exists.
- [x] Template Manager screen exists.
- [x] Contact Groups screen exists.
- [x] Backup and Restore screen exists.
- [x] CSV Import and Export screen exists.
- [x] Reliability screen exists.
- [x] Battery Optimization screen exists.
- [x] Notification Sound Test screen exists.
- [x] Crash Diagnostics screen exists.
- [x] Permissions and Privacy screen exists.
- [x] Device Setup Guides screen exists.
- [x] SMS and MMS Policy screen exists.
- [x] RCS and WhatsApp Policy screen exists.
- [x] WhatsApp Setup screen exists with Business API readiness checklist.
- [x] WhatsApp Manual Handoff screen exists.
- [x] Update Spotlight screen exists.
- [x] Native SMS service exists through the Flutter method channel.
- [x] Android SMS backend uses SmsManager for real SMS sending.
- [x] Android sent and delivered callback plumbing exists.
- [x] Background alarm sync service exists.

### Incomplete functional work

- [x] Add Direct Send to the Home menu.
- [x] Prove Direct Send end to end on a real phone.
- [x] Require approved or consented contacts before Direct Send.
- [x] Log Direct Send attempts to Send History.
- [x] Log Direct Send attempts to Message Timeline.
- [x] Show sent-to-Android versus carrier-delivered status clearly.
- [x] Verify delivery receipts update the UI after Android callbacks.
- [x] WhatsApp Manual Handoff opens the WhatsApp composer and requires manual send.
- [x] Open and highlight the edited app section after each update.
- [x] Build a real pending Send Queue view.
- [x] Add cancel controls for pending queued messages.
- [x] Add retry controls for failed messages.
- [x] Add duplicate-send guard using a stable send id.
- [ ] Enforce Do Not Send before every SMS send path.
- [ ] Block group sends when any recipient is in Do Not Send.
- [ ] Prove scheduled reminder flow end to end.
- [ ] Persist scheduled reminders before syncing alarms.
- [ ] Sync scheduled reminders to native Android alarms.
- [ ] Confirm BackgroundSmsReceiver sends due messages.
- [ ] Rehydrate queue after app restart.
- [ ] Rehydrate queue after phone reboot.
- [ ] Rehydrate queue after app update.
- [x] Add backup schema version checks.
- [x] Add backup restore validation before import.
- [x] Add restore duplicate prevention.
- [ ] Add a real phone regression test report section.
- [x] Add a guard that blocks home_screen.dart if it contains a pasted Windows path.

### Suggested next features to finish

1. Direct Send Home Route: expose the existing DirectSmsScreen from Home and test a real SMS.
2. Direct Send History Logging: write each send attempt, success, failure, and callback state to Send History and Message Timeline.
3. Scheduled Send End-to-End: connect reminder creation, local persistence, alarm sync, receiver send, and status logging.
4. Send Queue Controls: add pending queue, cancel, retry, max attempts, and duplicate-send guard.
5. Do Not Send Enforcement: block every direct, scheduled, and group send before SMS is attempted.
6. Delivery Status Mapping: separate queued, attempting, sent-to-Android, delivered, failed, blocked, skipped, and retrying.
7. Backup Integrity Verifier: validate backup version, required fields, duplicate ids, and restore safety before import.
8. Reboot and Update Recovery: make the app resync pending reminders after reboot and app update.
9. Home Source Guard: add a script check that fails if home_screen.dart starts with C:\Users or other pasted local path text.
10. Real Phone Release Report: add a repeatable checklist for build, install, copy APK, force-stop, relaunch, Direct Send test, and scheduled send test.

## Build rules

Before pushing main, run the guarded build flow:

- Check English-only ASCII text.
- Run flutter pub get.
- Run dart format lib.
- Run flutter analyze.
- Build the APK.
- Install the APK on the connected Android phone.
- Copy the APK to the phone Downloads folder.
- Force-stop the app.
- Relaunch the app.

## Android package

Default package id:

com.example.text_helper

## SMS-only policy

Text Helper currently sends SMS text messages only.

Supported:

- Plain SMS reminders.
- Appointment reminders.
- Follow-up texts.
- Confirmation texts.
- Scheduled text-only messages.

Not supported yet:

- MMS.
- Images.
- Videos.
- Audio files.
- PDF files.
- Contact cards.
- GIFs, stickers, or other media attachments.

The app should say "Sent to Android SMS service" unless a real Android carrier or device delivery callback is received. It should not claim "Delivered" unless Android provides a delivery receipt.

## Release gate

Before pushing main, the project must pass:

- English-only ASCII text check.
- Flutter dependency restore.
- Dart formatting.
- Flutter analyzer.
- APK build.
- APK install on a connected Android phone.
- APK copy to phone Downloads.
- App force-stop.
- App relaunch.

## Release gate checklist

Use this checklist before each push to main:

- [ ] git status is clean or changes are intentionally staged.
- [ ] README checklist is updated when a feature is completed.
- [ ] flutter pub get passes.
- [ ] dart format lib passes.
- [ ] flutter analyze passes.
- [ ] flutter build apk --debug passes.
- [ ] APK installs on the connected Android phone.
- [ ] APK is copied to /sdcard/Download/text-helper-debug.apk.
- [ ] App force-stop and relaunch passes.
- [ ] Direct Send test passes when Direct Send is changed.
- [ ] Scheduled send test passes when scheduler code is changed.
## Git safety guards

This repo includes local Git hooks and validation scripts to prevent common broken pushes.

Setup once after cloning:

    git config core.hooksPath .githooks

Before committing or pushing, the hooks run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_repo.ps1

The validator blocks:

- Missing local Dart imports.
- Untracked source files that were forgotten.
- Non-ASCII text in source, README, Android XML, or Kotlin files.
- Pasted Windows paths in home_screen.dart.

Use this script for the standard build/install gate:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\safe_build_install.ps1