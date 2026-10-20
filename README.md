# Baby Log

Track feeds (left / right / both / bottle, time, how long), nappies (pee / poo / both), sleep and your own pills
with reminder alarms. Two devices share the data over Wi-Fi by scanning a QR code or typing a code.

Use Flutter **3.47.7** (Dart 3.13.5) and Java 21. Add Flutter's `bin` directory to PATH.

## Install on Windows

Download `BabyLog-<version>-windows-x64.zip` from
[Releases](https://github.com/ChristopherVR/baby-log/releases), extract the entire ZIP,
and run `baby_app.exe`. Keep the DLLs and `data` folder together with the executable.
The ZIP includes the Visual C++ runtime; Flutter, Visual Studio and Developer Mode are
not required to run it.

Keep Baby Log open on the PC and phone on the same local network. Allow the Windows
Firewall prompt for **private networks**. On the phone, scan the PC's pairing QR code
in Settings, or type its address and code. The PC can pair by typing the phone's
address and code too. Windows uses the same Wi-Fi sync protocol, incremental changes,
merge rules, version checks and address rediscovery as Android. The PC can display
QR codes; camera scanning is available only on phones. Closing the PC app stops syncing.

Resize the window to suit your screen. Wider windows use side navigation and put today's
care controls beside the activity log; narrow windows keep bottom navigation and one column.
The refresh button in the top bar runs the same sync as pull-to-refresh, with progress and
result feedback. Your selected tab and history search stay in place when resizing.

To update, close the app and extract the new ZIP into a new folder. Local data is
stored separately and is preserved. Windows has no in-app updater.

## Develop and test on the PC

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
flutter build apk --flavor github --release
adb install build\app\outputs\flutter-apk\app-github-release.apk   # or copy the APK to the phone
```

Or with the phone plugged in (USB debugging on): `flutter run --flavor github`.

## GitHub and Google Play Android builds

Two Android flavors share the same application ID (`com.babyapp.baby_app`),
versioning, data format and Wi-Fi/QR sync logic:

- `github`: preserves the existing APK signing key, GitHub update check and APK installer.
- `play`: has no APK installer, installation permission or update FileProvider. The version
  dialog opens Google Play, which manages updates. Play releases require a separate upload
  key and never fall back to debug signing.

Build the Play bundle after configuring signing:

```powershell
flutter build appbundle --flavor play --release
# build/app/outputs/bundle/playRelease/app-play-release.aab
```

For local signing, copy `android/play-signing.properties.example` to
`android/play-signing.properties` and fill in your upload keystore path, alias and passwords.
The filled-in file and keystores are ignored by Git. Back up the upload keystore and credentials
outside the repository. Environment variables override the local file:
`PLAY_UPLOAD_KEYSTORE_PATH`, `PLAY_UPLOAD_STORE_PASSWORD`, `PLAY_UPLOAD_KEY_ALIAS`,
`PLAY_UPLOAD_KEY_PASSWORD`.

For CI, configure these repository Actions secrets:

| Secret | Value |
| --- | --- |
| `PLAY_UPLOAD_KEYSTORE` | Base64-encoded upload keystore file |
| `PLAY_UPLOAD_STORE_PASSWORD` | Keystore password |
| `PLAY_UPLOAD_KEY_ALIAS` | Upload key alias |
| `PLAY_UPLOAD_KEY_PASSWORD` | Key password |

When the keystore secret exists, every main release also builds and verifies a Play AAB using
that release's shared version and notes. Download the `BabyLog-<version>-play-internal` artifact
from the successful Actions run. It contains `BabyLog-<version>-play.aab`; it is not attached to
GitHub Releases. An absent `PLAY_UPLOAD_KEYSTORE` secret skips the Play job without affecting
APK/Windows releases. If a key is configured but invalid or incomplete, publication fails.
The Actions summary explains when Play was skipped; no Play account access or key is needed
until you are ready to enable AAB builds.
The workflow verifies both the merged manifest and the AAB's upload certificate before upload.

In your existing Play Console account, create Baby Log, confirm the package ID on the first
bundle upload, configure Play App Signing, and upload the AAB under **Testing → Internal testing**.
Add tester email addresses and share the opt-in link after rolling out the internal test.
This workflow prepares the downloadable AAB; it does not publish to Play Console automatically.

The current alarm/full-screen permissions and `specialUse` foreground sync service still require
review and applicable Play Console declarations. Store listing, privacy policy, Data safety and
other app-content setup are separate from building the bundle; generating an AAB does not confirm
Google Play approval.

**Existing GitHub installations:** Play App Signing uses a different signing certificate from the
current debug-signed APKs. Despite the same package ID, Play cannot simply replace those copies.
Export a JSON backup before uninstalling the GitHub copy, then install from Play and restore the
backup. Do not uninstall without a backup. The two channels cannot be installed side by side.
Once enrolled, future Play installations should update through Play; GitHub installations continue
using the existing GitHub key. Keep Play's version codes increasing when uploading subsequent bundles.

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
  the pencil edits their name, date of birth and profile photo. Existing logs stay with the original baby automatically.
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

## Growth journal and feeding breaks

- **Growth → Add a moment** saves a dated photo, weight in kg, height in cm and/or a memory.
  Add one each month or whenever you like. Tap a moment to edit or delete it; Undo restores it.
- The journal groups moments by month, shows age from the birthday, compares the first and latest
  photos, and charts recorded weight and height using actual dates. These are observed changes,
  not predicted growth or medical percentiles. Missing measurements are left out of their chart.
- Profile photos and journal photos are picked from JPG, PNG or WebP files (up to 20 MB), resized
  to at most 720 pixels and stored with the records. They survive restarts, JSON backup/restore
  and Wi-Fi sync. Photo-heavy journals can exceed the QR transfer limit; use Wi-Fi or a JSON backup.
  Use version 1.5 on both phones when syncing the new fields.
- **Feed → Start timer** begins active feeding time. **Pause to burp** freezes the count and
  cancels reminders; **Resume feeding** continues from the same count. **Stop & save** records
  active time (rounded to minutes), excluding every break. Cancel asks before discarding the feed.
  Both running and paused timers survive app restarts and keep the original baby selected.
- **Every 5 minutes** enables/disables a gentle reminder at each five minutes of active feeding.
  After pausing at 3 minutes, the next reminder is 2 minutes after resuming. Android schedules
  these as visible timer alarms with a single notification chime, including with the screen off;
  pause, stop and disabling reminders cancel the schedule. Tapping the reminder opens the app.
  Android notification and exact-alarm permissions must be enabled. A system next-alarm indicator
  may be shown while the feeding timer runs. Windows reminders work while the app is open.

## Sleep and history charts

- On Today, tap **Start nap** when putting your baby down. The start time can be adjusted.
  Tap **End nap** when they wake. Opening Feed or Nappy during a nap asks whether it finished;
  choose **Still sleeping** to continue tracking while logging the feed or change.
- Naps belong to the selected baby, survive restarts, and sync like other care entries.
  Tap a sleep entry in History to correct its times or delete it.
- **History** is the activity log, with search, entry-type filters and grouping. Filter to today,
  yesterday, a chosen day or date range, then optionally one hour of each day. CSV export uses
  the entries shown. Use the day arrows to move between individual dates.
- The **Charts** button opens a separate screen with its own date and hour filters. Switch
  between daily totals and hourly patterns. Daily charts include feeds, wees, poos, sleep,
  recorded feeding minutes, bottle volume and pills; hourly charts show feeds, wees, poos and
  sleep duration. Each chart shows totals, daily averages, peaks and exact bar values.
- Mixed nappies count as both wee and poo. Overnight sleep is split across hours and days;
  ongoing naps contribute up to now. Ranges use local calendar days. Today is incomplete,
  and empty days count as zero. Tap a bar for details; swipe to see the whole range.
- Next-day estimates average completed days in the selected range, including empty days,
  and exclude today. They appear with logs on at least three completed days and all hours
  selected. Missing logs affect estimates. Sleep is included in CSV exports and JSON backups.

## Languages

Choose **English** or **Afrikaans** on the first setup screen or in **Settings → Language**.
The choice takes effect immediately and is saved on that device. App controls, date pickers,
dates and reminders use the chosen language. Each phone keeps its own choice.

## Nighttime appearance

From 6 pm to 6 am in the phone's local time, the entire app uses its dark palette, including
settings, sheets and dialogs. It switches automatically while open and when returning to the
app. At 6 am it returns to the selected Light, Dark or Match phone appearance. The saved
appearance and selected log date do not change.
A small moon indicator explains "Dark mode for nighttime · until 6 am" across all screens,
and disappears during the day, including when the selected appearance stays dark.

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

## Automatic Android and Windows releases

Tap **Settings → This device → App version** to check GitHub for a stable release and open
the update controls. Checks run only when you tap the version. Internet access is needed;
baby logs are not sent to GitHub.

Tap **Update** to download with progress, then confirm Android's installation prompt. The first
time, Android may ask you to allow installations from Baby Log; return and tap **Update** again.
The downloaded APK is reused. Cancelling leaves the current app usable. Updates preserve local data.
Before opening the installer, Baby Log checks download size, package identity, increasing Android
build code and matching signing certificate. Android also verifies the APK during installation.
Windows releases are downloaded and updated manually using the ZIP. The Android updater is for GitHub APK distribution;
a future Play Store build needs Play's update flow.

Each new push to `main` cancels older queued or running release workflows, so rapid pushes
collapse into a release of the newest revision. Manual reruns of stale revisions cannot publish.

Release notes are generated by git-cliff using `cliff.toml`, covering all changes since the last
published stable release (including changes from cancelled builds). The same notes are published
on GitHub and bundled offline inside both builds. On the first foreground launch of that version,
Baby Log shows **What's new** once. Dismissing it is remembered on that device, across restarts;
this acknowledgement is neither synced nor included in backups. Development builds without
matching bundled notes do not show the dialog. Commit subjects become the release notes, so
write them as clear descriptions of the changes.

Every push to `main` runs static analysis, Flutter tests and versioning tests first. Only after they
pass does GitHub Actions prepare one shared version and release notes, then build the Android APK
and Windows x64 ZIP. Windows also runs the Flutter tests, including the Wi-Fi sync transport test.
Both builds must succeed before the workflow publishes their artifacts together on the repository's
[Releases](https://github.com/ChristopherVR/baby-log/releases) page.

`pubspec.yaml` is the version baseline. CI advances the shared patch version and build number for each
workflow run, updating the build checkout without adding bot commits to `main`. With baseline
`1.5.0+7`, the first push releases `1.5.0+8`, the second `1.5.1+9`, and so on. Failed runs may leave
gaps; retrying a run keeps its version. Update the baseline to start a new minor or major series.

The `ANDROID_DEBUG_KEYSTORE` Actions secret holds the existing signing key as base64, so automated
APKs can update the current installation. The workflow restores it only on the runner and never
commits it. This uses the app's existing debug signing configuration for family distribution.

Local baby logs, WhatsApp imports and exports stay outside Git. `/import/`, `/output/`, machine
settings, keystores and generated build artifacts are ignored. The repository contains source code,
assets, tests, build configuration and CI.
