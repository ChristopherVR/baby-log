# Foreground service declaration (Google Play)

Play Console → Policy and programs → App content → **Foreground service permissions**.

## Permission and type

- `FOREGROUND_SERVICE_SPECIAL_USE` (`foregroundServiceType="specialUse"`), service `.SyncService`.
- Manifest subtype (`PROPERTY_SPECIAL_USE_FGS_SUBTYPE`): "Local Wi-Fi server that shares the baby log
  with a partner's device".

## Description of the feature

Nestling keeps one baby log (feeds, nappies, sleep) shared between parents' phones. It has no
cloud server or account: the phones sync directly with each other over the home Wi-Fi network.
Each phone runs a small local HTTP server that the paired phone connects to when its parent logs
something.

When the user turns on Settings → Sync → "Keep syncing when closed", the foreground service keeps
that local server running after the app is closed, so an entry made on one parent's phone (for
example a 3 a.m. feed) appears on the other parent's phone without that parent having to open the
app first. The service shows a persistent, low-priority notification ("Sharing your log over
Wi-Fi") the whole time, and the user can turn it off in Settings at any time. It holds no Wi-Fi
or wake lock; a short wake lock is taken only while an incoming sync is processed.

## Why no other API or type fits

- The service must **receive** connections from the other phone at any moment, so WorkManager,
  JobScheduler and exact alarms cannot do it: they only run the app now and then, and the other
  phone's server is then almost never up at the same time.
- There is no server or Firebase Cloud Messaging to push from: the data never leaves the local
  network.
- `dataSync` is time-limited (6 hours a day on Android 15) and meant for one-off transfers, not
  for waiting for incoming connections. `connectedDevice` is for peripherals (Bluetooth, USB, etc.).

## User impact if the system defers or stops it

The partner's phone stops receiving entries until the app is opened again. During night feeds
this means the other parent cannot see when the baby last ate or which side was used, which is
the core purpose of the app.

## Demo video

Shows one device logging a nappy change while the other has the app in the background, and the
entry already being there when the other device is brought back. Recorded on two Windows copies
of the Play build (Play wording); a closing card describes the Android setting and its ongoing
notification, which the recording itself does not show.

https://github.com/ChristopherVR/baby-log/releases/download/v1.5.27/nestling-background-sync-demo.mp4
