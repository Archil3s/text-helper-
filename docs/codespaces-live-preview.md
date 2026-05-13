# Codespaces live preview

Use this workflow when ChatGPT or another device pushes updates to GitHub and you want your open Codespace preview to update.

## One-time setup

Open the Codespace terminal and run:

```bash
git pull
flutter pub get
.devcontainer/start_web.sh
```

Open the preview from:

```text
Ports -> 3000 -> Open in Browser
```

## After a GitHub update is pushed

Run this in the Codespace terminal:

```bash
git pull
flutter pub get
```

Then press this in the Flutter terminal:

```text
R
```

That hot-restarts the Flutter web preview.

## If the preview stops

Run:

```bash
.devcontainer/start_web.sh
```

Then open port 3000 again.

## Why this is not fully automatic

The Codespace does not automatically pull new GitHub commits into an already-open editor. This protects local work from being overwritten.

Safe live workflow:

```text
Push to GitHub
Pull in Codespaces
Press R in Flutter terminal
Preview updates
```

## Current MVP screen

The app currently opens the contact scheduler as the home screen. It includes:

- Contact book
- Add, edit, and delete contacts
- Contact search
- Tags and notes
- Scheduled text list
- Due, sent, and cancelled statuses
- Open SMS composer for a scheduled text

Automatic background SMS sending still requires native Android scheduling or a backend SMS provider.
