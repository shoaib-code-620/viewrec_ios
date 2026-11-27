import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/data.dart';
import 'package:viewrec/repo.dart';
import 'package:viewrec/screens/billing.dart';
import 'package:viewrec/screens/pricing.dart';
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
  await _pumpFor(t, 3000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  test('the plans match the website: three priced, one custom', () {
    expect([for (final p in plans) p.price], [49, 149, 299, 0]);
    expect(plans.last.custom, isTrue);
    expect(plans.where((p) => p.recommended).single.name, 'Pro');
  });

  test('changing the plan, stopping and adding a card are kept by the sample data', () async {
    final r = MockRepo();
    expect((await r.billing()).plan, 'Pro');
    await r.changePlan('plus');
    expect((await r.billing()).plan, 'Pro Plus');
    await r.stopSubscription();
    final stopped = await r.billing();
    expect(stopped.stopped, isTrue);
    expect(stopped.endsOn, isNotEmpty);
    await r.resumeSubscription();
    expect((await r.billing()).stopped, isFalse);
    await r.startCardSetup();
    expect((await r.billing()).cardLabel, 'Visa ending 4242');
    await r.removeCard();
    expect((await r.billing()).hasCard, isFalse);
    expect((await r.billing()).invoices.any((i) => i.status == 'pending'), isTrue);
  });

  testWidgets('Plan & billing shows the plan, the payments with Paid and Pending, and Stop', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: BillingTabs())));
    await _pumpFor(t, 2500);
    expect(find.text('Plan & billing'), findsOneWidget);
    expect(find.text('Refer and earn'), findsOneWidget);
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Change your plan'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Payments'), 300, scrollable: list);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Paid'), findsWidgets);
    await t.scrollUntilVisible(find.textContaining('keep the month'), 300, scrollable: list);
    await t.ensureVisible(find.text('Stop your subscription').last);
    await _pumpFor(t, 300);
    await t.tap(find.text('Stop your subscription').last);
    await _pumpFor(t, 600);
    expect(find.text('Stop your subscription?'), findsOneWidget);
    await t.tap(find.text('Keep it'));
    await _pumpFor(t, 400);
    await _finish(t);
  });

  testWidgets('Change your plan marks the current plan and switching asks first', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const PricingScreen()));
    await _pumpFor(t, 2500);
    final list = find.byType(Scrollable).first;
    expect(find.text('Change your plan'), findsOneWidget);
    expect(find.text('Your plan'), findsWidgets);
    await t.scrollUntilVisible(find.text('Switch to Pro Plus'), 300, scrollable: list);
    await t.ensureVisible(find.text('Switch to Pro Plus'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Switch to Pro Plus'));
    await _pumpFor(t, 600);
    expect(find.text('Switch to Pro Plus?'), findsOneWidget);
    await t.tap(find.text('Not now'));
    await _pumpFor(t, 400);
    await t.scrollUntilVisible(find.text('Talk to our team'), 300, scrollable: list);
    expect(find.text('Custom'), findsOneWidget);
    await _finish(t);
  });
}
