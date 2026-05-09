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