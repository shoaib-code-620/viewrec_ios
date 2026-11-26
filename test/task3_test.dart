import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/screens/publishing_where.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';
import 'package:viewrec/web_data.dart';

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
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

Future<void> _openSearch(WidgetTester t) async {
  await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 0)));
  await _pumpFor(t, 2500);
  await t.tap(find.byIcon(Icons.search_rounded));
  await _pumpFor(t, 1200);
}

Future<void> _finish(WidgetTester t) async {
  await _pumpFor(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('Publishing opens on Where they go, with the three steps and the channel list', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 7)));
    await _pumpFor(t, 2500);
    expect(find.text('Where they go'), findsOneWidget);
    expect(find.text('Queue & history'), findsOneWidget);
    expect(find.text('On your website'), findsOneWidget);
    expect(find.text('Something to publish'), findsOneWidget);
    expect(find.text('Your business verified'), findsOneWidget);
    expect(find.text('An account connected'), findsOneWidget);
    expect(find.text('Facebook Page'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('Add a destination: a website needs a real address, and then shows its signing secret', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: PublishingWhereScreen())));
    await _pumpFor(t, 2500);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.textContaining('Nowhere to publish yet'), 300, scrollable: list);
    expect(find.textContaining('Nowhere to publish yet'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Add destination'), 300, scrollable: list);
    await t.enterText(find.byType(TextField).first, 'My website');
    await t.enterText(find.byType(TextField).last, 'not a web address');
    await t.ensureVisible(find.text('Add destination'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Add destination'));
    await _pumpFor(t, 800);
    expect(find.textContaining('full web address'), findsOneWidget, reason: 'a bad address is refused');
    await t.enterText(find.byType(TextField).last, 'https://example.com/hooks/viewrec');
    await t.ensureVisible(find.text('Add destination'));
    await _pumpFor(t, 300);
    await t.tap(find.text('Add destination'));
    await _pumpFor(t, 1000);
    await t.scrollUntilVisible(find.text('Copy signing secret'), -300, scrollable: list);
    expect(find.text('Copy signing secret'), findsOneWidget);
    expect(find.textContaining('Nowhere to publish yet'), findsNothing);
    await _finish(t);
  });

  test('destinations are stored, a website gets a secret, and they can be removed', () async {
    final w = MockWebRepo();
    expect(await w.destinations(), isEmpty);
    final site = await w.addDestination(kind: 'website', name: 'Site', url: 'https://example.com/hook');
    expect(site.secret, startsWith('whsec_'));
    final hand = await w.addDestination(kind: 'li', name: 'Company page');
    expect(hand.secret, isEmpty);
    expect((await w.destinations()).length, 2);
    await w.deleteDestination(site.id);
    expect((await w.destinations()).single.kind, 'li');
    expect(() => w.addDestination(kind: 'website', name: 'Bad', url: 'nope'), throwsException);
  });

  testWidgets('Search finds pages by what you call them, not just by name', (t) async {
    await _phone(t);
    await _openSearch(t);
    expect(find.text('TRY SEARCHING FOR'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'reminder');
    await _pumpFor(t, 600);
    expect(find.text('Calendar'), findsOneWidget, reason: 'reminders live in the calendar');
    expect(find.text('Automations'), findsOneWidget);
    expect(find.text('Invitations sent'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('Search finds customers, and a tap opens them', (t) async {
    await _phone(t);
    await _openSearch(t);
    await t.enterText(find.byType(TextField), 'sarah');
    await _pumpFor(t, 1500);
    expect(find.text('CUSTOMERS'), findsOneWidget);
    expect(find.text('Sarah Mitchell'), findsWidgets);
    await t.tap(find.text('Sarah Mitchell').first);
    await _pumpFor(t, 1200);
    expect(find.text('Search the app'), findsNothing, reason: 'moved on to the contact');
    await _finish(t);
  });

  testWidgets('Search says so when nothing matches, and remembers what you searched', (t) async {
    await _phone(t);
    await _openSearch(t);
    await t.enterText(find.byType(TextField), 'zzzzqx');
    await _pumpFor(t, 600);
    expect(find.textContaining('No results for'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'invoice');
    await _pumpFor(t, 400);
    await t.tap(find.text('Plan & billing'));
    await _pumpFor(t, 1500);
    // back to the search later: the word is in Recent
    await _finish(t);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('recent_searches'), contains('invoice'));
  });
}
