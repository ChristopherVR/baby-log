import 'package:baby_app/src/ui/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pulling down a short list starts a refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PullToSync(
          onRefresh: () async => refreshed++,
          // Short content, like an empty Today page: it must still be pullable.
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [Text('Nothing yet')]),
        ),
      ),
    ));

    await tester.fling(find.text('Nothing yet'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });
}
