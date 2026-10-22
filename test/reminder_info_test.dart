import 'package:baby_app/src/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder payload round-trips and marks alarms the way MainActivity.kt looks for', () {
    const info = ReminderInfo(
      id: 101,
      kind: 'pill',
      medId: 'm1',
      title: 'Pill time: Iron',
      body: 'Take 1',
      alarm: true,
    );
    final payload = info.toPayload();
    expect(payload, contains('"alarm":true'));
    final back = ReminderInfo.parse(payload)!;
    expect(
      (back.id, back.kind, back.medId, back.alarm),
      (101, 'pill', 'm1', true),
    );
    expect(
      const ReminderInfo(id: 1, kind: 'feed', title: '', body: '').toPayload(),
      isNot(contains('"alarm":true')),
    );
    expect(ReminderInfo.parse('not json'), isNull);
  });
}
