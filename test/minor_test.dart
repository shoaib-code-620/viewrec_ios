import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/media_profile.dart';
import 'package:viewrec/screens/billing.dart';
import 'package:viewrec/screens/record.dart';
import 'package:viewrec/screens/welcome.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  SharedPreferences.setMockInitialValues({});
}

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester t) async {
  await _pump(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('Welcome has Get started and Sign in at the top and at the bottom', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const WelcomeScreen()));
    await _pump(t, 3000);
    expect(find.text('Sign in'), findsOneWidget, reason: 'at the top');
    expect(find.text('Get started'), findsOneWidget, reason: 'the small button at the top');
    await t.scrollUntilVisible(find.textContaining('Get started for'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Get started for'), findsOneWidget, reason: 'the main button at the bottom');
    expect(find.text('Sign in'), findsOneWidget, reason: 'and the one at the bottom');
    await _finish(t);
  });

  testWidgets('The customer recording flow offers a camera or an avatar, and no written review', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const RecordScreen(initialStage: Stage.choose)));
    await _pump(t, 2500);
    expect(find.text('Record a video'), findsOneWidget);
    expect(find.text('Use an avatar'), findsOneWidget);
    expect(find.text('Write it instead'), findsNothing);
    await _finish(t);
  });

  testWidgets('Home says good morning, afternoon or evening and what needs you', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
    await _pump(t, 3000);
    expect(find.textContaining(RegExp(r'Good (morning|afternoon|evening|night)\. ')), findsOneWidget);
    await _finish(t);
  });

  testWidgets('The messages button in the top bar is a paper plane', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
    await _pump(t, 2500);
    expect(find.byIcon(Icons.send_outlined), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    await _finish(t);
  });

  testWidgets('A public profile shows who follows the business and its highlights', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const PublicProfileScreen(businessId: 'b1')));
    await _pump(t, 3500);
    expect(find.textContaining('Followed by'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Our team'), findsOneWidget);
    await t.tap(find.text('Reviews'));
    await _pump(t, 1200);
    expect(find.text('What our customers say'), findsWidgets, reason: 'the highlight opens as a story');
    await _finish(t);
  });

  testWidgets('Plan & billing has a Refer and earn tab', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: BillingTabs())));
    await _pump(t, 1500);
    expect(find.text('Refer and earn'), findsOneWidget);
    await _finish(t);
  });
}
