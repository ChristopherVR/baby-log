import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_ble/universal_ble.dart';

import 'jieli.dart';
import 'models.dart';
import 'momcozy.dart';
import 'pump_session.dart';
import 'pump_tracking.dart';
import 'store.dart';

class BlePumpTransport implements PumpTransport {
  final String deviceId;
  final String service;
  final String writeChar;
  final String notifyChar;

  /// Wait for the write to be acknowledged; the pump channel does not.
  final bool withResponse;

  BlePumpTransport(
    this.deviceId, {
    required this.service,
    required this.writeChar,
    required this.notifyChar,
    this.withResponse = false,
  });

  @override
  Stream<List<int>> get incoming =>
      UniversalBle.characteristicValueStream(deviceId, notifyChar);

  @override
  Future<void> send(Uint8List bytes) => UniversalBle.write(
    deviceId,
    service,
    writeChar,
    bytes,
    withoutResponse: !withResponse,
  );
}

/// A pump seen while scanning.
class FoundPump {
  final BleDevice device;

  /// Null for devices shown only because "show all" is on.
  final int? productCode;

  FoundPump(this.device, this.productCode);

  String get id => device.deviceId;
  PumpModel? get model =>
      productCode == null ? null : PumpModel.fromCode(productCode!);
  String get name => device.name?.isNotEmpty == true ? device.name! : id;
}

enum PumpLinkState { connecting, ready, failed }

class ConnectedPump {
  final String id;
  final String name;
  PumpSession? session;
  PumpLinkState state = PumpLinkState.connecting;
  String? error;

  /// From the pump's JieLi chip, once read.
  JieliTargetInfo? firmware;
  List<PumpLogLine> firmwareLog = const [];
  StreamSubscription<bool>? _connection;

  ConnectedPump(this.id, this.name);

  FeedSide? get side => switch (session?.status?.sideCode) {
    0 => FeedSide.left,
    1 => FeedSide.right,
    _ => null,
  };

  PumpModel? get model => session?.info == null ? null : session!.model;

  String get label => switch (side) {
    FeedSide.left => 'Left pump',
    FeedSide.right => 'Right pump',
    _ => name,
  };
}

/// Finds, connects and follows Momcozy pumps, and sends controls to one or
/// both of them.
class PumpHub extends ChangeNotifier {
  PumpHub._();
  static final instance = PumpHub._();

  AppState? _app;

  final found = <String, FoundPump>{};
  final pumps = <String, ConnectedPump>{};
  bool scanning = false;

  /// List every Bluetooth device, not only ones that look like pumps.
  bool showAll = false;

  /// Controls go to every connected pump, like the app's bilateral sync.
  bool both = true;

  String? problem;
  StreamSubscription<BleDevice>? _scan;
  Timer? _poll;

  /// The session running now, across both pumps.
  final run = PumpRun();

  /// A session that just ended on the pumps, waiting to be saved.
  Entry? finished;

  Iterable<ConnectedPump> get ready =>
      pumps.values.where((p) => p.state == PumpLinkState.ready);

  /// Pumps are a phone feature; the desktop builds leave them out.
  static bool get supported =>
      supportedOverride ?? (!kIsWeb && Platform.isAndroid);

  @visibleForTesting
  static bool? supportedOverride;

  /// Links the hub to the app's saved pumps; safe to call again.
  void attach(AppState app) => _app = app;

  void setShowAll(bool v) {
    showAll = v;
    notifyListeners();
  }

  void setBoth(bool v) {
    both = v;
    notifyListeners();
  }

  Future<bool> _prepare() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {
      problem = 'Nestling needs the Nearby devices permission to find pumps.';
      notifyListeners();
      return false;
    }
    var state = await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.poweredOff) {
      await UniversalBle.enableBluetooth();
      state = await UniversalBle.getBluetoothAvailabilityState();
    }
    if (state != AvailabilityState.poweredOn) {
      problem = 'Turn on Bluetooth to find pumps.';
      notifyListeners();
      return false;
    }
    problem = null;
    return true;
  }

  Future<void> startScan() async {
    if (scanning || !await _prepare()) return;
    found.clear();
    scanning = true;
    notifyListeners();
    _scan = UniversalBle.scanStream.listen(_onScan);
    await UniversalBle.startScan();
    Timer(const Duration(seconds: 15), stopScan);
  }

  void _onScan(BleDevice d) {
    int? code;
    for (final m in d.manufacturerDataList) {
      code ??= momcozyProductCodeOf(m.companyId, m.payload);
    }
    // The advert may come without manufacturer data (e.g. a scan response).
    if (code == null &&
        d.services.map(BleUuidParser.string).contains(momcozyAdvertService)) {
      code = found[d.deviceId]?.productCode ?? PumpModel.m5Pro.code;
    }
    if (code == null && !showAll) return;
    // Keep a pump's code when a later advert lacks it.
    code ??= found[d.deviceId]?.productCode;
    found[d.deviceId] = FoundPump(d, code);
    notifyListeners();
  }

  Future<void> stopScan() async {
    if (!scanning) return;
    scanning = false;
    await _scan?.cancel();
    _scan = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    notifyListeners();
  }

  /// Connects every saved pump that is not connected yet. Pumps that are
  /// switched off just fail quietly.
  Future<void> connectSaved() async {
    final app = _app;
    if (app == null || app.pumpDevices.isEmpty || !await _prepare()) return;
    await Future.wait([
      for (final e in app.pumpDevices.entries)
        if (pumps[e.key]?.state != PumpLinkState.ready &&
            pumps[e.key]?.state != PumpLinkState.connecting)
          connect(e.key, e.value['name'] as String? ?? 'Pump', quiet: true),
    ]);
  }

  /// Connects a pump. [model] is the user's pick for a pump that does not
  /// say what it is; it is remembered.
  Future<void> connect(
    String id,
    String name, {
    bool quiet = false,
    PumpModel? model,
  }) async {
    final saved = _app?.pumpDevices[id]?['modelOverride'] as int?;
    final override =
        model ?? (saved == null ? null : PumpModel.fromCode(saved));
    if (pumps[id]?.state == PumpLinkState.connecting) return;
    await stopScan();
    pumps.remove(id)?.session?.dispose();
    final p = ConnectedPump(id, name);
    pumps[id] = p;
    notifyListeners();
    try {
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
      final services = await UniversalBle.discoverServices(id);
      final uuids = {for (final s in services) BleUuidParser.string(s.uuid)};
      final v3 = uuids.contains(BleUuidParser.string(momcozyServiceUuidV3));
      if (!v3 && !uuids.contains(BleUuidParser.string(momcozyServiceUuid))) {
        throw PumpException('This device has no Momcozy pump service');
      }
      try {
        await UniversalBle.requestMtu(id, momcozyMtu);
      } catch (_) {
        // Some phones fix the MTU themselves; history reads may then fail.
      }
      final t = BlePumpTransport(
        id,
        service: v3 ? momcozyServiceUuidV3 : momcozyServiceUuid,
        writeChar: v3 ? momcozyWriteUuidV3 : momcozyWriteUuid,
        notifyChar: v3 ? momcozyNotifyUuidV3 : momcozyNotifyUuid,
      );
      final session = PumpSession(t)
        ..modelOverride = override
        ..addListener(() => _onStatus(p));
      p.session = session;
      p._connection = UniversalBle.connectionStream(id).listen((up) {
        if (!up) _drop(id, 'Disconnected');
      });
      await UniversalBle.subscribeNotifications(id, t.service, t.notifyChar);
      await session.start();
      p.state = PumpLinkState.ready;
      _app?.rememberPump(id, {
        'name': name,
        'serial': session.info?.serial,
        'model': session.info?.productCode,
        'modelOverride': ?override?.code,
        'firmware': session.info?.firmwareVersion,
        'hardware': session.info?.hardwareVersion,
        'side': session.status?.sideCode,
        ..._snapshot(session.status),
      });
      _poll ??= Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
      notifyListeners();
      await importHistory(p);
    } catch (e) {
      p.state = PumpLinkState.failed;
      p.error = quiet ? 'Not reachable. Is it switched on?' : '$e';
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
    notifyListeners();
  }

  void _onStatus(ConnectedPump p) {
    final s = p.session?.status;
    final side = p.side;
    if (s != null && side != null) _track(side, s);
    // Keep what a disconnected pump last showed, saving only on change.
    final saved = _app?.pumpDevices[p.id];
    if (s != null && saved != null && saved['battery'] != s.battery) {
      _app!.rememberPump(p.id, _snapshot(s));
    }
    notifyListeners();
  }

  Map<String, dynamic> _snapshot(PumpStatus? s) => {
    'lastSeen': DateTime.now().millisecondsSinceEpoch,
    if (s != null) ...{'battery': s.battery, 'milkMl': s.milkMl},
  };

  void _track(FeedSide side, PumpStatus s) {
    if (run.update(side, s, DateTime.now())) {
      finished = run.draft(DateTime.now());
      run.reset();
    }
  }

  void _drop(String id, String reason) {
    final p = pumps[id];
    if (p == null || p.state == PumpLinkState.failed) return;
    p.state = PumpLinkState.failed;
    p.error = reason;
    if (_app?.pumpDevices.containsKey(id) == true) {
      _app!.rememberPump(id, _snapshot(p.session?.status));
    }
    // A pump that switches off mid-session usually drops before it says so.
    final s = p.session?.status, side = p.side;
    if (run.active && s != null && side != null) {
      _track(
        side,
        PumpStatus(
          battery: s.battery,
          runStateCode: PumpRunState.off.code,
          sideCode: s.sideCode,
          modeCode: s.modeCode,
          level: s.level,
          frequency: s.frequency,
          totalSeconds: s.totalSeconds,
          modeSeconds: s.modeSeconds,
          modeTotalSeconds: s.modeTotalSeconds,
          milkMl: s.milkMl,
          errorCode: s.errorCode,
        ),
      );
    }
    notifyListeners();
  }

  /// Status pushes stop while a pump sits idle, so ask now and then.
  void _refresh() {
    final now = DateTime.now();
    for (final p in ready) {
      final s = p.session!;
      // Skip pumps busy with a command or that just sent their status.
      final last = s.lastStatusAt;
      if (s.busy ||
          (last != null && now.difference(last) < const Duration(seconds: 2))) {
        continue;
      }
      s.refreshStatus().catchError((_) => null);
    }
    if (ready.isEmpty) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> disconnect(String id) async {
    final p = pumps.remove(id);
    if (p == null) return;
    if (_app?.pumpDevices.containsKey(id) == true) {
      _app!.rememberPump(id, _snapshot(p.session?.status));
    }
    await p._connection?.cancel();
    p.session?.dispose();
    try {
      await UniversalBle.disconnect(id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> forget(String id) async {
    await disconnect(id);
    _app?.forgetPump(id);
    notifyListeners();
  }

  /// Runs [action] on [target], or on every ready pump when it is null.
  Future<void> control(
    ConnectedPump? target,
    Future<void> Function(PumpSession s) action,
  ) async {
    final targets = target == null ? ready.toList() : [target];
    final errors = <String>[];
    await Future.wait([
      for (final p in targets)
        action(p.session!).catchError((Object e) {
          errors.add('${p.label}: $e');
        }),
    ]);
    problem = errors.isEmpty ? null : errors.join('\n');
    notifyListeners();
  }

  /// Ends the live session by hand (e.g. the pumps stayed on).
  Entry? finishNow() {
    if (!run.active) return null;
    final d = run.draft(DateTime.now());
    run.reset();
    notifyListeners();
    return d;
  }

  Entry? takeFinished() {
    final f = finished;
    finished = null;
    return f;
  }

  /// Reads a pump's stored log, which empties it on the pump, keeps the raw
  /// records in pump_history.jsonl and lists the sessions they describe.
  Future<List<PumpHistoryRecord>> importHistory(ConnectedPump p) async {
    final s = p.session!;
    final records = await s.readHistory();
    if (records.isEmpty) return records;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/pump_history.jsonl');
    await file.writeAsString(
      '${[
        for (final r in records) jsonEncode({'pump': s.info?.serial, 'side': s.status?.sideCode, 'time': r.time.millisecondsSinceEpoch, 'event': r.eventCode, 'state': r.runStateCode, 'mode': r.modeCode, 'level': r.level, 'battery': r.battery, 'milkMl': r.milkMl, 'vibration': r.vibration, 'heating': r.heating, 'posture': r.posture}),
      ].join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
    final app = _app;
    final side = p.side;
    if (app != null && side != null) {
      final sessions = sessionsFromHistory(records, side: side);
      final logged = app.pumpEntries.toList();
      app.setPumpFound(
        mergeSides([...app.pumpFound, ...sessions])
            .where((e) => !alreadyLogged(e, logged)),
      );
    }
    notifyListeners();
    return records;
  }

  /// Asks the pump's JieLi chip for its exact firmware version, battery and
  /// whether it keeps a backup copy while updating. Read-only.
  Future<JieliTargetInfo> readFirmware(ConnectedPump p) async {
    final services = await UniversalBle.discoverServices(p.id);
    final service = services
        .where((s) => s.uuid == BleUuidParser.string(jieliServiceUuid))
        .firstOrNull;
    if (service == null) {
      throw JieliException('This pump has no firmware channel');
    }
    final write = service.characteristics
        .where((c) => c.uuid == BleUuidParser.string(jieliWriteUuid))
        .firstOrNull;
    final t = BlePumpTransport(
      p.id,
      service: jieliServiceUuid,
      writeChar: jieliWriteUuid,
      notifyChar: jieliNotifyUuid,
      withResponse:
          write?.properties.contains(CharacteristicProperty.write) ?? true,
    );
    final session = JieliSession(t);
    try {
      await UniversalBle.subscribeNotifications(
        p.id,
        jieliServiceUuid,
        jieliNotifyUuid,
      );
      final info = await session.targetInfo();
      p.firmware = info;
      _app?.rememberPump(p.id, {
        'fwVersion': ?info.version,
        'dualBank': ?info.dualBank,
      });
      return info;
    } finally {
      p.firmwareLog = session.log;
      session.dispose();
      try {
        await UniversalBle.unsubscribe(p.id, jieliServiceUuid, jieliNotifyUuid);
      } catch (_) {}
      notifyListeners();
    }
  }

  /// The raw packet log of every connected pump, for sharing.
  String logText() => [
    for (final p in pumps.values) ...[
      '# ${p.label} ${p.session?.info?.serial ?? p.id} '
          'fw ${p.session?.info?.firmwareVersion}',
      ...?p.session?.log.map((l) => '$l'),
      if (p.firmwareLog.isNotEmpty) '# firmware channel',
      ...p.firmwareLog.map((l) => '$l'),
    ],
  ].join('\n');
}
