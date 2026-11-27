import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/insights.dart';
import 'package:viewrec/screens/media_viewers.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

Future<void> _pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _home(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  C.special = false;
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
  await _pumpFor(t, 3000);
}

/// The blue results card is the third card of the swipeable top of Home.
Future<void> _toResults(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('hero_dot_2')));
  await _pumpFor(t, 1200);
}

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('The blue card shows a real trend and its chart opens Insights', (t) async {
    await _home(t);
    await _toResults(t);
    expect(find.textContaining('views this week'), findsOneWidget, reason: 'the trend comes from the weekly views, not a fixed number');
    expect(find.text('See details'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('hero_chart')));
    await _pumpFor(t, 1500);
    expect(find.byType(InsightsScreen), findsOneWidget);
    await _finish(t);
  });

  testWidgets('The count, rating and waiting pill take you to the reviews', (t) async {
    await _home(t);
    await _toResults(t);
    for (final k in ['hero_count', 'hero_rating', 'hero_videos']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('hero_count')));
    await _pumpFor(t, 1500);
    expect(find.byKey(const ValueKey('hero_count')), findsNothing, reason: 'moved off Home to Reviews');
    await _finish(t);
  });

  testWidgets('Get started lists the real workflow steps, a few at a time, and opens the right page', (t) async {
    await _home(t);
    await t.scrollUntilVisible(find.text('Get started'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byKey(const ValueKey('check_Add your logo')), findsOneWidget);
    expect(find.text('Show all 13 steps'), findsOneWidget);
    expect(find.byKey(const ValueKey('check_Set your reminders')), findsNothing, reason: 'done steps are hidden until you ask for all');
    await t.ensureVisible(find.byKey(const ValueKey('check_toggle')));
    await _pumpFor(t, 300);
    await t.tap(find.byKey(const ValueKey('check_toggle')));
    await _pumpFor(t, 600);
    expect(find.text('Show less'), findsOneWidget);
    expect(find.byKey(const ValueKey('check_Set your reminders')), findsOneWidget);
    expect(find.byKey(const ValueKey('check_Publish your first video')), findsOneWidget);
    await _finish(t);
  });

  testWidgets('Home opens on the camera card with the welcome typing itself in different fonts', (t) async {
    await _home(t);
    expect(find.byKey(const ValueKey('hero_pager')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_dot_0')), findsOneWidget);
    // the text grows while it is typed
    int typed() => (t.widget(find.byKey(const ValueKey('hero_typed'))) as Text).textSpan!.toPlainText().length;
    final early = typed();
    await _pumpFor(t, 3000);
    expect(typed(), greaterThan(early));
    await _pumpFor(t, 12000);
    expect(find.text('Camera is off'), findsOneWidget, reason: 'there is no camera in the test, so it says so');
    expect(find.byKey(const ValueKey('hero_camera_retry')), findsOneWidget);
    final text = (t.widget(find.byKey(const ValueKey('hero_typed'))) as Text).textSpan!.toPlainText();
    expect(text, contains('welcome to ViewRec'));
    expect(text, contains('Hey Jordan,'));
    expect(text, contains('Hartley Roofing'));
    expect(text, contains('engagement'));
    final fonts = <String?>{};
    final sizes = <double?>{};
    (t.widget(find.byKey(const ValueKey('hero_typed'))) as Text).textSpan!.visitChildren((s) {
      if (s is TextSpan && s.text != null && s.text!.trim().isNotEmpty) {
        fonts.add(s.style?.fontFamily);
        sizes.add(s.style?.fontSize);
      }
      return true;
    });
    expect(fonts.length, greaterThanOrEqualTo(3), reason: 'more than one font');
    expect(sizes.length, greaterThanOrEqualTo(4), reason: 'more than one size');
    await _finish(t);
  });

  testWidgets('You can swipe between the camera, your reels and the results card', (t) async {
    await _home(t);
    await t.drag(find.byKey(const ValueKey('hero_pager')), const Offset(-500, 0));
    await _pumpFor(t, 1200);
    expect(find.text('Your reels'), findsOneWidget);
    expect(find.text('Tap to watch'), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('hero_pager')), const Offset(-500, 0));
    await _pumpFor(t, 1200);
    expect(find.byKey(const ValueKey('hero_count')), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('hero_pager')), const Offset(500, 0));
    await t.drag(find.byKey(const ValueKey('hero_pager')), const Offset(500, 0));
    await _pumpFor(t, 1200);
    expect(find.byKey(const ValueKey('hero_record')), findsOneWidget);
    await _finish(t);
  });

  testWidgets('The reels card plays your posts one after another and opens the viewer', (t) async {
    await _home(t);
    await t.tap(find.byKey(const ValueKey('hero_dot_1')));
    await _pumpFor(t, 1200);
    expect(find.textContaining('post'), findsWidgets);
    final first = find.descendant(of: find.byKey(const ValueKey('hero_reels')), matching: find.byType(Text)).evaluate().length;
    expect(first, greaterThan(3));
    await _pumpFor(t, 5000);
    expect(find.text('Your reels'), findsOneWidget, reason: 'still showing after it moved on to the next reel');
    await t.tap(find.byKey(const ValueKey('hero_reels')));
    await _pumpFor(t, 1500);
    expect(find.byType(ReelsViewer), findsOneWidget, reason: 'the full-screen viewer opened on top');
    await _finish(t);
  });
}
