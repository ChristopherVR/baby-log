import 'dart:io';

import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppState> _device(String name, List<Directory> dirs) async {
  final dir = await Directory.systemTemp.createTemp('baby-hub-');
  dirs.add(dir);
  final app = await AppState.loadForTesting(File('${dir.path}/app.json'));
  app.deviceName = name;
  await app.startServerForTesting();
  return app;
}

void main() {
  late List<Directory> dirs;
  late List<AppState> apps;
  setUp(() {
    dirs = [];
    apps = [];
    AppState.appVersion = '1.5.0';
  });
  tearDown(() async {
    for (final a in apps) {
      a.dispose();
      await a.pendingSave;
    }
    for (final d in dirs) {
      await d.delete(recursive: true);
    }
  });

  Future<AppState> make(String name) async {
    final a = await _device(name, dirs);
    apps.add(a);
    return a;
  }

  test('joining one member joins the whole hub', () async {
    final a = await make('Mum');
    final b = await make('Dad');
    final c = await make('Nanny');

    final feed = Entry(
      type: EntryType.feed,
      time: DateTime.now(),
      side: FeedSide.left,
    );
    a.addEntry(feed);
    await a.pair('127.0.0.1', b.server.port!, b.syncKey);
    await c.pair('127.0.0.1', b.server.port!, b.syncKey);
    // C already heard about A from B.
    expect(
      c.peers.map((p) => p.deviceId),
      containsAll([a.deviceId, b.deviceId]),
    );
    expect(
      c.peers.firstWhere((p) => p.deviceId == a.deviceId).learnedFromHub,
      isTrue,
    );
    expect(c.entries.map((e) => e.id), contains(feed.id));

    // A hears about C the next time it syncs with B.
    await a.syncAll(force: true);
    expect(
      a.peers.map((p) => p.deviceId),
      containsAll([b.deviceId, c.deviceId]),
    );

    // A and C now sync directly: a change on C reaches A without B in between.
    final bottle = Entry(
      type: EntryType.feed,
      time: DateTime.now(),
      side: FeedSide.right,
    );
    c.addEntry(bottle);
    final direct = a.peers.firstWhere((p) => p.deviceId == c.deviceId);
    await a.syncPeer(direct);
    expect(a.entries.map((e) => e.id), contains(bottle.id));
    expect(direct.lastError, isNull);
    expect(direct.lastSync, isNotNull);
    expect(a.syncHasError, isFalse);
  });

  test(
    'a removed member is not re-added by gossip, until paired again',
    () async {
      final a = await make('Mum');
      final b = await make('Dad');
      final c = await make('Nanny');
      await a.pair('127.0.0.1', b.server.port!, b.syncKey);
      await c.pair('127.0.0.1', b.server.port!, b.syncKey);
      await a.syncAll(force: true);
      final c1 = a.peers.firstWhere((p) => p.deviceId == c.deviceId);
      a.forgetPeer(c1);
      expect(a.peers.map((p) => p.deviceId), [b.deviceId]);

      // B still lists C, but A ignores it.
      await a.syncAll(force: true);
      await a.syncAll(force: true);
      expect(a.peers.map((p) => p.deviceId), [b.deviceId]);

      // The removal survives a restart.
      await a.pendingSave;
      final again = await AppState.loadForTesting(File(a.dataFilePath));
      apps.add(again);
      expect(again.peers.map((p) => p.deviceId), [b.deviceId]);

      // Pairing explicitly brings it back.
      await a.pair('127.0.0.1', c.server.port!, c.syncKey);
      expect(
        a.peers.map((p) => p.deviceId),
        containsAll([b.deviceId, c.deviceId]),
      );
    },
  );

  test('unreachable gossiped members are not an error', () async {
    final a = await make('Mum');
    final b = await make('Dad');
    await a.pair('127.0.0.1', b.server.port!, b.syncKey);
    b.peers.add(
      Peer(
        deviceId: 'gone',
        host: '127.0.0.1',
        port: 9,
        key: '111111',
        name: 'Gran',
      )..learnedFromHub = true,
    );
    await a.syncAll(force: true);
    final error = await a.syncAll(force: true);
    expect(error, isNull);
    final gran = a.peers.firstWhere((p) => p.deviceId == 'gone');
    expect(gran.neverReached, isTrue);
    expect(gran.lastError, isNotNull);
    expect(a.syncHasError, isFalse);
  });

  test('gossip never replaces a key or a working address', () async {
    final a = await make('Mum');
    final b = await make('Dad');
    final c = await make('Nanny');
    await a.pair('127.0.0.1', b.server.port!, b.syncKey);
    await a.pair('127.0.0.1', c.server.port!, c.syncKey);
    final cAtA = a.peers.firstWhere((p) => p.deviceId == c.deviceId);
    final port = cAtA.port;
    b.peers.add(
      Peer(
        deviceId: c.deviceId,
        host: '10.9.9.9',
        port: 1,
        key: '000000',
        name: 'X',
      ),
    );
    await a.syncAll(force: true);
    expect(cAtA.host, '127.0.0.1');
    expect(cAtA.port, port);
    expect(cAtA.key, c.syncKey);
  });

  test('members survive a restart', () async {
    final a = await make('Mum');
    final b = await make('Dad');
    final c = await make('Nanny');
    await a.pair('127.0.0.1', b.server.port!, b.syncKey);
    await c.pair('127.0.0.1', b.server.port!, b.syncKey);
    await a.syncAll(force: true);
    await a.pendingSave;
    final again = await AppState.loadForTesting(File(a.dataFilePath));
    apps.add(again);
    expect(
      again.peers.map((p) => p.deviceId),
      containsAll([b.deviceId, c.deviceId]),
    );
  });
}
