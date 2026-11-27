import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/repo.dart';
import 'package:viewrec/screens/avatar.dart';
import 'package:viewrec/screens/billing.dart';
import 'package:viewrec/screens/media_insights.dart';
import 'package:viewrec/screens/record.dart';
import 'package:viewrec/theme.dart';

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  SharedPreferences.setMockInitialValues({});
}

Future<void> _pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 2000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  final now = DateTime(2026, 11, 27);
  test('the card form refuses bad numbers, dates and codes', () {
    String? e({String n = '4242 4242 4242 4242', String name = 'A Person', String x = '12/29', String c = '123'}) => cardError(number: n, name: name, expiry: x, cvc: c, now: now);
    expect(e(), isNull);
    expect(e(n: '4242 4242 4242 4241'), contains('card number'));
    expect(e(n: '1234'), contains('card number'));
    expect(e(name: ' '), contains('name'));
    expect(e(x: '13/29'), contains('month'));
    expect(e(x: '1229'), contains('MM/YY'));
    expect(e(x: '10/26'), contains('expired'));
    expect(e(c: '12'), contains('security code'));
  });

  testWidgets('Change your card opens the short form, formats what is typed and saves', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const PaymentMethodScreen(current: '')));
    await _pumpFor(t, 600);
    expect(find.text('Card details'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'A Person');
    await t.enterText(find.byType(TextField).at(1), '4242424242424242');
    await t.enterText(find.byType(TextField).at(2), '1229');
    await t.enterText(find.byType(TextField).at(3), '123');
    await _pumpFor(t, 300);
    expect(find.text('4242 4242 4242 4242'), findsOneWidget);
    expect(find.text('12/29'), findsOneWidget);
    await t.ensureVisible(find.text('Save card'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Save card'));
    await _pumpFor(t, 3000);
    expect(find.text('Visa ending 4242'), findsWidgets);
    expect(find.text('Change your card'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('The avatar builder changes the face and reports it', (t) async {
    await _phone(t);
    AvatarSpec? got;
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: Scaffold(body: SingleChildScrollView(child: AvatarBuilder(onChanged: (v) => got = v)))));
    await _pumpFor(t, 300);
    await t.tap(find.byKey(const ValueKey('Skin3')));
    await t.tap(find.text('Curly'));
    await t.ensureVisible(find.text('Round'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Round'));
    await _pumpFor(t, 300);
    expect(got, const AvatarSpec(skin: 3, hairStyle: 3, glasses: 1));
    await _finish(t);
  });

  testWidgets('Making an avatar that looks like you is offered before recording', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const RecordScreen(initialStage: Stage.avatar)));
    await _pumpFor(t, 600);
    expect(find.text('Make one that looks like you'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('avatar_me')));
    await _pumpFor(t, 600);
    expect(find.text('Hair colour'), findsOneWidget);
    expect(find.text('Continue to recording'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('Media insights shows reach and changes with the period', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const MediaInsightsScreen()));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await _pumpFor(t, 800);
    expect(find.text('Accounts reached'), findsOneWidget);
    final first = (t.widget(find.byKey(const ValueKey('reach'))) as Text).data;
    await t.tap(find.text('Last 30 days'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await _pumpFor(t, 800);
    expect((t.widget(find.byKey(const ValueKey('reach'))) as Text).data, isNot(first));
    expect((await t.runAsync(() => MockRepo().mediaInsights(7)))!.topPosts, isNotEmpty);
    await _finish(t);
  });
}
