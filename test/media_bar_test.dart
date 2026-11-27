import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: kMediaIndex)));
  await _pump(t, 3000);
}

/// Whether the label is on screen at full opacity (a bar that has slid away is faded out).
bool _visible(WidgetTester t, String label) {
  final fade = find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)).first;
  return t.widget<AnimatedOpacity>(fade).opacity == 1;
}

Future<void> _finish(WidgetTester t) async {
  await _pump(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('The Media page has the Instagram-style bar instead of the normal one', (t) async {
    await _open(t);
    expect(find.bySemanticsLabel('Feed'), findsOneWidget);
    expect(find.bySemanticsLabel('Explore'), findsOneWidget);
    expect(find.bySemanticsLabel('Create'), findsOneWidget);
    expect(find.bySemanticsLabel('Reels'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Your profile')), findsOneWidget);
    expect(_visible(t, 'Reviews'), isFalse, reason: 'the normal bar has slid away on Media');
    expect(_visible(t, 'More'), isFalse);
    await _finish(t);
  });

  testWidgets('Your profile is one tap from the bar, shows likes, and has Edit profile', (t) async {
    await _open(t);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Your profile')));
    await _pump(t, 3500);
    expect(find.text('@hartleyroofing'), findsWidgets);
    expect(find.text('Likes'), findsOneWidget, reason: 'the total likes is in the header');
    expect(find.text('Edit profile'), findsOneWidget);
    await t.scrollUntilVisible(find.byIcon(Icons.favorite_rounded), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets, reason: 'each post shows its likes');
    expect(find.text('Follow'), findsNothing, reason: 'you do not follow yourself');
    await _finish(t);
  });

  testWidgets('Explore searches businesses and shows a grid with likes', (t) async {
    await _open(t);
    await t.tap(find.bySemanticsLabel('Explore'));
    await _pump(t, 3000);
    expect(find.text('Explore'), findsWidgets);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    await t.enterText(find.byType(TextField), 'dental');
    await _pump(t, 800);
    expect(find.text('Brightside Dental'), findsWidgets);
    expect(find.text('Accounts'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('Back from Explore goes to the feed first, then leaves Media', (t) async {
    await _open(t);
    await t.tap(find.bySemanticsLabel('Explore'));
    await _pump(t, 2500);
    await t.binding.handlePopRoute();
    await _pump(t, 1200);
    expect(find.text('Search businesses and reviews'), findsNothing, reason: 'back to the feed');
    await t.binding.handlePopRoute();
    await _pump(t, 1500);
    final instaFade = find.ancestor(of: find.byIcon(Icons.add_box_outlined), matching: find.byType(AnimatedOpacity)).first;
    expect(t.widget<AnimatedOpacity>(instaFade).opacity, 0, reason: 'back on Home: the Instagram-style bar has slid away');
    expect(_visible(t, 'Reviews'), isTrue);
    await _finish(t);
  });

  testWidgets('Opening Media slides the normal bar down while the Instagram-style bar rises, and back', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
    await _pump(t, 3000);
    final reviews = find.text('Reviews');
    final restY = t.getTopLeft(reviews).dy;
    await t.tap(find.text('Media').first);
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 120));
    final midY = t.getTopLeft(reviews).dy;
    expect(midY, greaterThan(restY), reason: 'the normal bar is sliding down, not vanishing at once');
    await _pump(t, 800);
    final goneY = t.getTopLeft(reviews).dy;
    expect(goneY, greaterThan(midY), reason: 'and carries on down');
    // back: the normal bar rises again
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 120));
    expect(t.getTopLeft(reviews).dy, lessThan(goneY), reason: 'coming back up');
    await _pump(t, 800);
    expect(t.getTopLeft(reviews).dy, closeTo(restY, 1.5), reason: 'and settles where it started');
    await _finish(t);
  });
}
