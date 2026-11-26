import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/repo.dart';
import 'package:viewrec/screens/notifications.dart';
import 'package:viewrec/theme.dart';

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a notification can be tapped and opens what it is about; Mark all as read clears the dots', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const NotificationsScreen()));
    await _pump(t, 2500);
    expect(find.text('Lena Fischer recorded a video'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget, reason: 'some are unread');
    await t.tap(find.text('Lena Fischer recorded a video'));
    await _pump(t, 2500);
    expect(find.text('Testimonial'), findsOneWidget, reason: 'the tap opened the testimonial');
    expect(find.text('Capture check'), findsNothing);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _pump(t, 1500);
    expect((await t.runAsync(() => repo.notifications()))!.firstWhere((n) => n.id == 'n1').read, isTrue, reason: 'opening it marks it read');
    await t.tap(find.text('Mark all as read'));
    await _pump(t, 800);
    expect(find.text('Mark all as read'), findsNothing);
    expect((await t.runAsync(() => repo.notifications()))!.every((n) => n.read), isTrue);
    await _pump(t, 6000);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
