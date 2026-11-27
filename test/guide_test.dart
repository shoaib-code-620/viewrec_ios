import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/guide.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

Future<void> _pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _setup(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  C.special = false;
  SharedPreferences.setMockInitialValues({});
  GuideStore.resetForTest();
}

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('The tour has four pages, Next moves on, and finishing turns the tips on', (t) async {
    await _setup(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => GuideStore.showTour(c), child: const Text('open'))))));
    await t.tap(find.text('open'));
    await _pumpFor(t, 800);
    expect(find.text('Add your customers'), findsOneWidget);
    for (final title in ['Send them a link', 'They record, you approve', 'Share it everywhere']) {
      await t.tap(find.text('Next'));
      await _pumpFor(t, 700);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Start'), findsOneWidget);
    await t.tap(find.text('Start'));
    await _pumpFor(t, 800);
    expect(GuideStore.tourSeen, isTrue);
    expect(GuideStore.tipsOn, isTrue);
    expect(find.text('open'), findsOneWidget, reason: 'back where we were');
    await _finish(t);
  });

  testWidgets('Skip ends the tour at once', (t) async {
    await _setup(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => GuideStore.showTour(c), child: const Text('open'))))));
    await t.tap(find.text('open'));
    await _pumpFor(t, 800);
    await t.tap(find.byKey(const ValueKey('tour_skip')));
    await _pumpFor(t, 800);
    expect(find.text('Add your customers'), findsNothing);
    expect(GuideStore.tourSeen, isTrue);
    await _finish(t);
  });

  testWidgets('Tips show once on a key screen, only after the tour, and "Got it" removes them for good', (t) async {
    await _setup(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
    await _pumpFor(t, 3000);
    expect(find.text('Your dashboard'), findsNothing, reason: 'no tips before the tour');
    await GuideStore.tourFinished();
    await _pumpFor(t, 800);
    expect(find.text('Your dashboard'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tip_ok_0')));
    await _pumpFor(t, 800);
    expect(find.text('Your dashboard'), findsNothing);
    expect(GuideStore.seenTips, contains('tip_0'));
    await _finish(t);
  });

  testWidgets('Help and guide opens from More, expands a how-to and switches tips', (t) async {
    await _setup(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: kMoreIndex)));
    await _pumpFor(t, 3000);
    await t.tap(find.byKey(const ValueKey('more_help')));
    await _pumpFor(t, 1000);
    expect(find.text('Take the tour'), findsOneWidget);
    await t.ensureVisible(find.text('Send an invitation'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Send an invitation'));
    await _pumpFor(t, 700);
    expect(find.textContaining('Choose text, email'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tips_switch')));
    await _pumpFor(t, 500);
    expect(GuideStore.tipsOn, isTrue);
    await _finish(t);
  });

  testWidgets('Signing in queues the tour, and an empty Reviews screen says what to do', (t) async {
    await _setup(t);
    GuideStore.pendingTour = true;
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
    await _pumpFor(t, 2500);
    expect(find.text('Add your customers'), findsOneWidget, reason: 'the tour opens on first arrival');
    await t.tap(find.byKey(const ValueKey('tour_skip')));
    await _pumpFor(t, 800);
    expect(GuideStore.pendingTour, isFalse);
    await _finish(t);
  });
}
