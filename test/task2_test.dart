import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewrec/models.dart';
import 'package:viewrec/repo.dart';
import 'package:viewrec/screens/invitations.dart';
import 'package:viewrec/screens/lead_thread.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';
import 'package:viewrec/web_data.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(seconds: 2));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
}

void main() {
  testWidgets('long press a message, pick a reaction, it shows under the bubble and can be taken back', (t) async {
    await _phone(t);
    final lead = Lead(id: 'l1', name: 'Rebecca Shaw', service: 'Roof inspection', message: 'Hi, I saw your video reviews. Can someone look at a leak?', status: 'new', when: '1h', source: 'Website');
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: LeadThreadScreen(lead: lead)));
    await _settle(t);
    await t.longPress(find.textContaining('I saw your video reviews').first);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('👍'), findsOneWidget, reason: 'the reaction row is in the menu');
    await t.tap(find.text('👍'));
    await _settle(t);
    expect(find.text('👍'), findsOneWidget, reason: 'now shown as a chip under the message');
    await t.tap(find.text('👍'));
    await _settle(t);
    expect(find.text('👍'), findsNothing, reason: 'tapping your own reaction takes it back');
    final msg = find.textContaining('I saw your video reviews').first;
    await t.tap(msg);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(msg);
    await _settle(t);
    expect(find.text('❤️'), findsOneWidget, reason: 'double tap hearts a message');
    await t.pump(const Duration(seconds: 6));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets('Set reminder opens the form with date, about and repeat, and saves', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 17)));
    await _settle(t);
    await t.ensureVisible(find.text('Set reminder'));
    await t.tap(find.text('Set reminder'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Set a reminder'), findsOneWidget);
    expect(find.text('Remind me on'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Repeat every'), findsOneWidget);
    // the About box is required
    final submit = find.descendant(of: find.byType(BottomSheet), matching: find.text('Set reminder'));
    await t.ensureVisible(submit);
    await t.tap(submit);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Say what the reminder is about'), findsOneWidget);
    await t.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first, 'Call the Hendersons about their review');
    await t.tap(submit);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Remind me on'), findsNothing, reason: 'the form closed after saving');
    await t.pump(const Duration(seconds: 6));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets('Invitations sent lists invited people with reminders and a Remind button', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: InvitationsScreen())));
    await _settle(t);
    expect(find.text('Tom Hendricks'), findsOneWidget);
    expect(find.textContaining('Sent 29 Oct'), findsOneWidget);
    expect(find.textContaining('2 reminders'), findsOneWidget);
    expect(find.text('Remind'), findsOneWidget);
    await t.tap(find.text('Remind'));
    await _settle(t);
    expect(find.textContaining('3 reminders'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  test('groups keep their purpose and note, and a group of two is allowed', () async {
    final w = MockWebRepo();
    final b = await w.saveBundle(name: 'kitchen', memberIds: ['1', '2'], purpose: 'approach', note: 'first approach to kitchen leads');
    expect(b.memberIds.length, 2);
    expect(b.purposeLabel, 'first approach');
    expect((await w.bundles()).first.note, 'first approach to kitchen leads');
  });

  test('a repeating reminder lands on the calendar every cycle', () async {
    final w = MockWebRepo();
    final d = DateTime.now().add(const Duration(days: 1));
    await w.createReminder(date: d, about: 'Call the Hendersons', repeatEveryDays: 7);
    final events = <CalendarEvent>[];
    for (var m = 0; m < 4; m++) {
      events.addAll(await w.calendarEvents(DateTime(d.year, d.month + m)));
    }
    expect(events.where((e) => e.title == 'Call the Hendersons').length, greaterThanOrEqualTo(10));
  });

  test('a reaction is kept by the sample data and can be removed', () async {
    final r = MockRepo();
    final msgs = await r.leadMessages('l1');
    await r.reactLeadMessage('l1', msgs.first.id, '🙏');
    expect((await r.leadMessages('l1')).first.myReaction, '🙏');
    await r.reactLeadMessage('l1', msgs.first.id, null);
    expect((await r.leadMessages('l1')).first.myReaction, isNull);
  });
}
