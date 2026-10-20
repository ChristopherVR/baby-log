import 'dart:convert';
import 'dart:io';

import 'package:baby_app/src/models.dart';
import 'package:baby_app/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Wi-Fi pairing exchanges deltas and receives edits and deletions',
    () async {
      final dir = await Directory.systemTemp.createTemp('baby-wifi-sync-');
      final app = await AppState.loadForTesting(File('${dir.path}/app.json'));
      AppState.appVersion = '1.5.0';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        app.dispose();
        await app.pendingSave;
        await dir.delete(recursive: true);
      });

      var remote = Entry(
        type: EntryType.nappy,
        time: DateTime.now(),
        nappy: NappyKind.pee,
      );
      var remoteSeq = 1;
      var knowsUs = false;
      final sent = <Map<String, dynamic>>[];
      final identity = {
        'deviceId': 'phone',
        'name': 'Phone',
        'appVersion': '1.5.0',
        'port': server.port,
      };
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/info') {
          expect(request.headers.value('x-babylog-key'), '123456');
          expect(request.headers.value('x-babylog-device'), app.deviceId);
          request.response.write(
            jsonEncode({...identity, 'seq': remoteSeq, 'knowsYou': knowsUs}),
          );
        } else {
          expect(request.uri.path, '/sync');
          expect(request.method, 'POST');
          final body = jsonDecode(
            await utf8.decodeStream(request),
          ) as Map<String, dynamic>;
          expect(body['key'], '123456');
          sent.add(body);
          knowsUs = true;
          request.response.write(
            jsonEncode({
              'from': identity,
              'seq': remoteSeq,
              'took': {'feed': (body['entries'] as List).length},
              'entries': [
                if ((body['since'] as int) < remoteSeq) remote.toJson(),
              ],
            }),
          );
        }
        await request.response.close();
      });

      final feed = Entry(
        type: EntryType.feed,
        time: DateTime.now(),
        side: FeedSide.left,
      );
      app.addEntry(feed);
      final peer = await app.pair('127.0.0.1', server.port, '123456');
      expect(peer.lastError, isNull);
      expect(app.entries.map((e) => e.id), containsAll([feed.id, remote.id]));
      expect((sent.single['entries'] as List).single['id'], feed.id);

      // No records changed: the /info request is enough, with no POST.
      await app.syncPeer(peer);
      expect(sent, hasLength(1));

      final next = Entry(
        type: EntryType.feed,
        time: DateTime.now(),
        side: FeedSide.right,
      );
      app.addEntry(next);
      await app.syncPeer(peer);
      expect((sent.last['entries'] as List).single['id'], next.id);
      expect(sent.last['since'], 1);

      remote = Entry(
        id: remote.id,
        type: remote.type,
        time: remote.time,
        nappy: NappyKind.both,
        updatedAt: remote.updatedAt.add(const Duration(seconds: 1)),
      );
      remoteSeq++;
      await app.syncPeer(peer);
      expect(
        app.entries.singleWhere((e) => e.id == remote.id).nappy,
        NappyKind.both,
      );
      expect(sent.last['entries'], isEmpty);

      remote = remote.copyWith(
        updatedAt: remote.updatedAt.add(const Duration(seconds: 1)),
        deleted: true,
      );
      remoteSeq++;
      await app.syncPeer(peer);
      expect(app.entries.map((e) => e.id), isNot(contains(remote.id)));
      expect(app.entries.map((e) => e.id), containsAll([feed.id, next.id]));
      expect(sent.last['entries'], isEmpty);
    },
  );
}
