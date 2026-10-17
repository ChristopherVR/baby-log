import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const defaultSyncPort = 8765;

/// Version reported by copies of the app from before versions were checked.
const olderVersion = 'older';

class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  @override
  String toString() => message;
}

/// The other device could not be reached at its address (off, asleep, or
/// moved to another address or network).
class UnreachableException extends SyncException {
  UnreachableException(super.message);
}

/// The other phone runs a different app version and syncing with it is paused.
class VersionMismatchException extends SyncException {
  final String deviceId;
  final String theirVersion;
  VersionMismatchException(this.deviceId, this.theirVersion)
      : super(theirVersion == olderVersion
            ? 'The other phone has an older version of the app'
            : 'The other phone has version $theirVersion');
}

/// Pairing info shown in the QR code: `babylog://pair?h=<ip>&p=<port>&k=<code>`.
class PairInfo {
  final String host;
  final int port;
  final String key;
  PairInfo(this.host, this.port, this.key);

  String toUri() => 'babylog://pair?h=$host&p=$port&k=$key';

  static PairInfo? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'babylog') return null;
    final h = uri.queryParameters['h'];
    final k = uri.queryParameters['k'];
    if (h == null || k == null) return null;
    return PairInfo(h, int.tryParse(uri.queryParameters['p'] ?? '') ?? defaultSyncPort, k);
  }
}

typedef SyncReply = ({int status, Map<String, dynamic>? body});

/// Answers requests from other devices while the app is open:
/// `GET /info` (who are you, which version) and `POST /sync` (exchange data).
class SyncServer {
  HttpServer? _server;

  /// Wrong-code attempts per address; 10 within 10 minutes locks it out.
  final _failures = <String, List<DateTime>>{};

  int? get port => _server?.port;

  Future<void> start({
    required SyncReply Function(String key, String askerId) onInfo,
    required Future<SyncReply> Function(Map<String, dynamic> body, String remoteIp) onSync,
  }) async {
    if (_server != null) return;
    // A second copy of the app on the same PC (for testing) takes the next port.
    for (var p = defaultSyncPort; p < defaultSyncPort + 10 && _server == null; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
      } on SocketException {
        // Port in use, try the next one.
      }
    }
    _server?.listen((req) async {
      final ip = req.connectionInfo?.remoteAddress.address ?? '';
      final now = DateTime.now();
      final fails = (_failures[ip] ?? [])..removeWhere((t) => now.difference(t).inMinutes >= 10);
      if (fails.length >= 10) {
        req.response.statusCode = HttpStatus.tooManyRequests;
        await req.response.close();
        return;
      }
      try {
        SyncReply? reply;
        if (req.method == 'GET' && req.uri.path == '/info') {
          reply = onInfo(req.headers.value('x-babylog-key') ?? '', req.headers.value('x-babylog-device') ?? '');
        } else if (req.method == 'POST' && req.uri.path == '/sync') {
          final body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
          reply = await onSync(body, ip);
        } else if (req.uri.path == '/ping') {
          req.response.write('babylog');
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        if (reply?.status == HttpStatus.forbidden) _failures[ip] = fails..add(now);
        if (reply != null) {
          req.response.statusCode = reply.status;
          if (reply.body != null) {
            req.response.headers.contentType = ContentType.json;
            req.response.add(utf8.encode(jsonEncode(reply.body)));
          }
        }
      } catch (e) {
        debugPrint('Sync request failed: $e');
        req.response.statusCode = HttpStatus.badRequest;
      }
      await req.response.close();
    });
  }
}

Future<T> _request<T>(String host, Future<T> Function(HttpClient client) run,
    {Duration connect = const Duration(seconds: 4), Duration total = const Duration(seconds: 20)}) async {
  if (host.isEmpty) throw UnreachableException('Address not known yet');
  final client = HttpClient()..connectionTimeout = connect;
  try {
    return await run(client).timeout(total);
  } on SocketException {
    throw UnreachableException('Could not reach $host. Is the app open on the same Wi-Fi?');
  } on TimeoutException {
    throw UnreachableException('Timed out reaching $host');
  } on HttpException {
    throw UnreachableException('Lost the connection to $host');
  } finally {
    client.close(force: true);
  }
}

/// Asks the other device who it is ([myId] lets it say whether it knows us).
/// Old versions without `/info` answer with an empty map.
Future<Map<String, dynamic>> getInfo(String host, int port, String key, String myId,
        {Duration connect = const Duration(seconds: 4), Duration total = const Duration(seconds: 20)}) =>
    _request(connect: connect, total: total, host, (client) async {
      final req = await client.get(host, port, '/info');
      req.headers.set('x-babylog-key', key);
      req.headers.set('x-babylog-device', myId);
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      if (res.statusCode == HttpStatus.forbidden) throw SyncException('Wrong code');
      if (res.statusCode == HttpStatus.tooManyRequests) throw SyncException('Too many wrong codes, try again in 10 minutes');
      if (res.statusCode == HttpStatus.notFound) return <String, dynamic>{};
      if (res.statusCode != HttpStatus.ok) throw SyncException('Other device answered ${res.statusCode}');
      return jsonDecode(text) as Map<String, dynamic>;
    });

/// Sends our data and returns the other device's answer plus the bytes moved.
Future<({Map<String, dynamic> body, int status, int bytes})> postSync(
        String host, int port, Map<String, dynamic> payload) =>
    _request(host, (client) async {
      final out = utf8.encode(jsonEncode(payload));
      final req = await client.post(host, port, '/sync');
      req.headers.contentType = ContentType.json;
      req.add(out);
      final res = await req.close();
      final bytesIn = await res.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      if (res.statusCode == HttpStatus.forbidden) throw SyncException('Wrong code');
      if (res.statusCode != HttpStatus.ok && res.statusCode != HttpStatus.conflict) {
        throw SyncException('Other device answered ${res.statusCode}');
      }
      return (
        body: jsonDecode(utf8.decode(bytesIn)) as Map<String, dynamic>,
        status: res.statusCode,
        bytes: out.length + bytesIn.length,
      );
    });

/// Looks for the device [deviceId] on this network (the /24 of [ownIp]) by
/// asking every address for its `/info` with that device's code. Returns its
/// address, or null. Only devices running the app answer at all.
Future<String?> findOnNetwork({
  required String ownIp,
  required int port,
  required String key,
  required String myId,
  required String deviceId,
}) async {
  final dot = ownIp.lastIndexOf('.');
  if (dot < 0) return null;
  final prefix = ownIp.substring(0, dot + 1);
  // Our own address is included: another copy of the app can run on this
  // device (testing), and this device's own answer never matches anyway.
  final candidates = [for (var i = 1; i < 255; i++) '$prefix$i'];
  String? found;
  // 32 at a time with short timeouts: the whole network takes a few seconds.
  for (var start = 0; start < candidates.length && found == null; start += 32) {
    final batch = candidates.skip(start).take(32);
    await Future.wait(batch.map((host) async {
      try {
        final info = await getInfo(host, port, key, myId,
            connect: const Duration(milliseconds: 800), total: const Duration(seconds: 2));
        if (info['deviceId'] == deviceId) found ??= host;
      } catch (_) {
        // Nothing there, or another device: keep looking.
      }
    }));
  }
  return found;
}

/// This device's LAN addresses, most likely Wi-Fi address first.
Future<List<String>> localIps() async {
  final scored = <(int, String)>[];
  try {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in ifaces) {
      final name = iface.name.toLowerCase();
      final isVirtual = const ['vethernet', 'wsl', 'virtualbox', 'vmware', 'docker', 'hyper-v', 'tailscale', 'zerotier']
          .any(name.contains);
      for (final a in iface.addresses) {
        final ip = a.address;
        if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
        var score = ip.startsWith('192.168.')
            ? 3
            : ip.startsWith('10.')
                ? 2
                : RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)
                    ? 1
                    : 0;
        if (isVirtual) score -= 5;
        if (name.contains('wlan') || name.contains('wi-fi') || name.contains('wifi')) score += 1;
        scored.add((score, ip));
      }
    }
  } catch (e) {
    debugPrint('Could not list network interfaces: $e');
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final s in scored) s.$2];
}
