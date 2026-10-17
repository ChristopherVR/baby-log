import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Sync data passed between phones as a series of QR codes, for when they
/// are not on the same Wi-Fi. The JSON is gzipped, base64 encoded and split
/// into parts: `BLQ1|<session>|<index>|<count>|<data>`. The sending phone
/// cycles through the parts; the scanning phone collects them in any order.
abstract final class QrTransfer {
  static const _prefix = 'BLQ1';

  /// Characters of data per QR code; small enough to scan easily off a screen.
  static const chunkSize = 700;

  /// More parts than this takes too long to scan.
  static const maxParts = 40;

  static List<String> encode(Map<String, dynamic> payload) {
    final packed = base64Url.encode(gzip.encode(utf8.encode(jsonEncode(payload))));
    final session = (Random.secure().nextInt(1 << 30)).toRadixString(36);
    final count = max(1, (packed.length / chunkSize).ceil());
    return [
      for (var i = 0; i < count; i++)
        '$_prefix|$session|$i|$count|${packed.substring(i * chunkSize, min(packed.length, (i + 1) * chunkSize))}',
    ];
  }

  static bool looksLikePart(String text) => text.startsWith('$_prefix|');
}

/// Collects scanned parts until a whole payload has arrived.
class QrCollector {
  String? _session;
  int _count = 0;
  final Map<int, String> _parts = {};

  int get received => _parts.length;
  int get total => _count;
  bool get done => _count > 0 && _parts.length == _count;

  /// Adds a scanned code. Returns true if it was a new part.
  bool add(String text) {
    final bits = text.split('|');
    if (bits.length != 5 || !QrTransfer.looksLikePart(text)) return false;
    final index = int.tryParse(bits[2]);
    final count = int.tryParse(bits[3]);
    if (index == null || count == null || index >= count) return false;
    // A different session (the other phone made a new code): start over.
    if (bits[1] != _session) {
      _session = bits[1];
      _count = count;
      _parts.clear();
    }
    if (_parts.containsKey(index)) return false;
    _parts[index] = bits[4];
    return true;
  }

  Map<String, dynamic> result() {
    final packed = [for (var i = 0; i < _count; i++) _parts[i]!].join();
    return jsonDecode(utf8.decode(gzip.decode(base64Url.decode(packed)))) as Map<String, dynamic>;
  }
}
