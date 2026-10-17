# Baby Log

Track feeds (left / right / both / bottle, time, how long), nappies (pee / poo / both) and your own pills
with reminder alarms. Two devices share the data over Wi-Fi by scanning a QR code or typing a code.

Use Flutter **3.47.7** (Dart 3.13.5) and Java 21. Add Flutter's `bin` directory to PATH.

## Test on the PC

Requires Windows **Developer Mode** (Settings → System → For developers), needed by Flutter plugins.

```powershell
flutter run -d windows
```

Test syncing on one PC with a second, separate copy (own data file, next free port):

```powershell
flutter build windows
.\build\windows\x64\runner\Release\baby_app.exe                 # device A (port 8765)
.\build\windows\x64\runner\Release\baby_app.exe --profile=b     # device B (port 8766)
```

In B: Settings (gear) → Type code → address `<A's IP>:8765` and A's code, or start B with
`--pair=127.0.0.1:8765:<A's code>` to pair automatically. Allow the Windows Firewall prompt
(private networks) so phones can reach the PC.

## Install on Android

```powershell
flutter build apk --release
adb install build\app\outputs\flutter-apk\app-release.apk   # or copy the APK to the phone
```

Or with the phone plugged in (USB debugging on): `flutter run`.

## How syncing works

- While the app runs, each device serves `GET /info` (name, app version, counts, change counter) and
  `POST /sync` on port 8765 (`lib/src/sync.dart`). Pairing: scan the QR code or type address + code.
- Only changes are sent: every record gets a number from a local change counter when it changes, and
  each paired device remembers what the other has confirmed (`ackedSeq` / `theirSeq`). Records are never
  echoed back to the phone they came from. If nothing changed on either side, a sync is one small request.
- Merging: newest `updatedAt` wins; an edit always beats the version it replaced (even with clock
  differences); exact ties resolve the same way on both phones. Deletes are tombstones.
- Each entry records which phone logged it; the same kind of entry from two phones within 10 minutes is
  flagged as a possible duplicate. Saving an edit that the other phone changed meanwhile asks first.
- Different app versions pause syncing until someone taps "Continue anyway" on the device's page.
- On screen the app checks every 2 minutes; local changes are pushed within a second. In the background
  (Android foreground service, `SyncService.kt`) there is no timer and no Wi-Fi lock; a wake lock is held
  only while a sync runs. Pill reminders ring only on the phone that added the pill unless switched on.
- Wrong codes: 10 from one address within 10 minutes locks that address out for 10 minutes.
- Address changes: if a paired phone cannot be reached, the app asks every address on its own /24
  network for that phone's `/info` (using the stored code) and updates the address when found. Only while
  on screen or when the user taps Sync now / Find on this Wi-Fi, at most every 10 minutes per phone.
  When this phone's own address changes it syncs right away, so the others learn it.
- No shared Wi-Fi: "Sync by QR code" (`lib/src/qr_transfer.dart`). The changes the other phone has not
  confirmed are gzipped and shown as a cycling series of QR codes (700 characters each, up to 40); the
  other phone scans them, then the two swap. Works for unpaired phones too (it pairs them).

## Baby profiles and routines

- Use the baby selector above the tabs to switch profiles. The person-plus button adds a baby;
  the pencil renames the selected baby. Existing logs stay with the original baby automatically.
- Feeds, nappies and routines belong to the selected baby. Feed reminder settings are separate
  for each baby on each phone. Pills continue to track the parent's medication across profiles.
- Open **Routines** to set up bath time, bedtime, tummy time or a custom activity. Choose a time,
  one or more weekdays and optional notes. Edit, pause or delete a routine whenever needed.
- Enable **Remind me on this device** for a weekly repeating notification on the selected days.
  Reminders include the baby's name and can be snoozed. Each phone chooses its own reminders;
  they continue for every baby even when another profile is selected.
- Use **Mark done** to record who did a routine and when, including earlier activities. The caregiver
  name is remembered on that phone. Cards show **Last done**, and **History** lists all completions.
  Remove a mistaken completion and use Undo to restore it. History remains when a routine is deleted.
- The Today screen shows the latest completion and the selected baby's next routine. A running feed timer must be saved
  or stopped before switching babies, so the feed stays with the right baby.
- Profiles and routines sync by Wi-Fi or QR and are included in JSON backups, including deletions.
  Install the same feature version on both phones to share profiles, routines and completion history.

## Languages

Choose **English** or **Afrikaans** on the first setup screen or in **Settings → Language**.
The choice takes effect immediately and is saved on that device. App controls, date pickers,
dates and reminders use the chosen language. Each phone keeps its own choice.

## Reminders

- **Feed**: bell on the "Last feed" card → remind X hours after the start of the last feed.
- **Pills**: "N times a day" (spread evenly over 24h) or "every X hours", from a first-dose time;
  the schedule restarts each day at that time. One repeating daily alarm per dose time.
- **Notification or alarm** (Settings, per phone, separately for feeds and pills). Alarm = the phone's
  alarm ringtone on the alarm stream, repeating until stopped (max 15 min), full screen on the lock
  screen, Stop / Snooze 10 min buttons (snooze works with the app closed, via a background handler in
  `lib/src/notifications.dart`). Opening it shows `AlarmPage` with Taken / Log feed. The app only shows
  over the lock screen while an alarm opened it (`MainActivity.kt`).

## Export and import

- History → ⋮ menu (or Settings → Your data): export a full backup (`.json`), export what History
  shows as a spreadsheet (`.csv`), or import a backup. Importing merges by id (newest wins) and
  never deletes anything, so importing the same file twice is harmless.
- Local baby data, WhatsApp imports, exports and APKs are excluded from Git. Backups should be kept separately.

## Automatic Android releases

Android checks GitHub for a stable release on opening/resuming the app (at most once every six
hours). A newer version with a matching `BabyLog-<version>.apk` shows **New update available**
above the tabs. **Settings → App updates → Check for updates** checks immediately.
Internet access is needed; baby logs are not sent to GitHub.

Tap **Update** to download with progress, then confirm Android's installation prompt. The first
time, Android may ask you to allow installations from Baby Log; return and tap **Update** again.
The downloaded APK is reused. Cancelling leaves the current app usable. Updates preserve local data.
Before opening the installer, Baby Log checks download size, package identity, increasing Android
build code and matching signing certificate. Android also verifies the APK during installation.
Windows remains a development/test target without an updater. This is for GitHub APK distribution;
a future Play Store build needs Play's update flow.

Every push to `main` runs static analysis, Flutter tests and versioning tests first. Only after they
pass does GitHub Actions build a release APK, upload an artifact and publish it on the repository's
[Releases](https://github.com/ChristopherVR/baby-log/releases) page.

`pubspec.yaml` is the version baseline. CI advances the patch version and Android build code for each
workflow run, updating the build checkout without adding bot commits to `main`. With baseline
`1.4.0+7`, the first push releases `1.4.0+8`, the second `1.4.1+9`, and so on. Failed runs may leave
gaps; retrying a run keeps its version. Update the baseline to start a new minor or major series.

The `ANDROID_DEBUG_KEYSTORE` Actions secret holds the existing signing key as base64, so automated
APKs can update the current installation. The workflow restores it only on the runner and never
commits it. This uses the app's existing debug signing configuration for family distribution.

Local baby logs, WhatsApp imports and exports stay outside Git. `/import/`, `/output/`, machine
settings, keystores and generated build artifacts are ignored. The repository contains source code,
assets, tests, build configuration and CI.
