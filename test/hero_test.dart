import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/insights.dart';
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

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('The blue card shows a real trend and its chart opens Insights', (t) async {
    await _home(t);
    expect(find.textContaining('views this week'), findsOneWidget, reason: 'the trend comes from the weekly views, not a fixed number');
    expect(find.text('See details'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('hero_chart')));
    await _pumpFor(t, 1500);
    expect(find.byType(InsightsScreen), findsOneWidget);
    await _finish(t);
  });

  testWidgets('The count, rating and waiting pill take you to the reviews', (t) async {
    await _home(t);
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
}
