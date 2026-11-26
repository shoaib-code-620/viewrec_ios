import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/data.dart';
import 'package:viewrec/screens/admin.dart';
import 'package:viewrec/screens/video_detail.dart';
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

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _scrollTo(WidgetTester t, Finder f) => t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

Future<void> _tapText(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await _pump(t, 300);
  await t.tap(f);
}

Future<void> _finish(WidgetTester t) async {
  await _pump(t, 6000);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('Automations has the website tabs: Scheduled first, then Defaults', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 5)));
    await _pump(t, 3000);
    expect(find.text('Scheduled'), findsWidgets);
    expect(find.text('Defaults'), findsOneWidget);
    expect(find.text('Remind me'), findsOneWidget);
    expect(find.text('Email a group'), findsOneWidget);
    expect(find.text('Run history'), findsOneWidget);
    await t.tap(find.text('Defaults'));
    await _pump(t, 2500);
    expect(find.text('Ask after every completed job'), findsOneWidget);
    expect(find.text('Remind me'), findsNothing, reason: 'the reminder card lives on the Scheduled tab');
    await _finish(t);
  });

  test('a scheduled group email and a reminder show on the calendar and can be cancelled', () async {
    final w = MockWebRepo();
    final day = DateTime.now().add(const Duration(days: 3));
    final b = (await w.bundles()).first;
    await w.scheduleGroupEmail(bundleId: b.id, date: day, subject: 'Hello', body: 'A message long enough to send.');
    await w.createReminder(date: day, about: 'Call the Hendersons');
    final mine = (await w.calendarEvents(DateTime(day.year, day.month))).where((e) => e.mine).toList();
    expect(mine.length, 2);
    expect(mine.any((e) => e.title.startsWith('Group email')), isTrue);
    await w.cancelScheduled(mine.first.id);
    expect((await w.calendarEvents(DateTime(day.year, day.month))).where((e) => e.mine).length, 1);
  });

  testWidgets('A testimonial with an unverified capture shows the signals and what is worth a look', (t) async {
    await _phone(t);
    final v = demoVideos()[2];
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: VideoDetailScreen(video: v)));
    await _pump(t, 1500);
    expect(find.text('Capture not verified'), findsOneWidget);
    expect(find.textContaining('Nothing was rejected'), findsOneWidget);
    expect(find.text('Consent given'), findsOneWidget);
    expect(find.text('Website'), findsWidgets);
    await _scrollTo(t, find.text('Worth a look'));
    expect(find.textContaining('same network'), findsOneWidget);
    await _scrollTo(t, find.textContaining('What was actually said'));
    expect(find.textContaining('words'), findsWidgets);
    await _finish(t);
  });

  testWidgets('Editing the transcript offers Save, and saving keeps it', (t) async {
    await _phone(t);
    final v = demoVideos()[2];
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: VideoDetailScreen(video: v)));
    await _pump(t, 1500);
    await _scrollTo(t, find.textContaining('What was actually said'));
    expect(find.text('Save transcript'), findsNothing);
    final field = find.widgetWithText(TextField, v.transcript);
    await t.ensureVisible(field);
    await t.enterText(field, 'Quick, tidy and very fair. I told my whole street about them.');
    await _pump(t, 400);
    expect(find.text('Save transcript'), findsOneWidget);
    await t.ensureVisible(find.text('Save transcript'));
    await _pump(t, 300);
    await t.tap(find.text('Save transcript'));
    await _pump(t, 1200);
    expect(find.text('Save transcript'), findsNothing, reason: 'saved, so nothing is pending');
    await _finish(t);
  });

  testWidgets('Admin control: invite a team member with view or edit per section, then change and remove them', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Scaffold(body: AdminScreen())));
    await _pump(t, 2500);
    expect(find.text('Invite a team member'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Always included'), findsOneWidget);
    // nothing ticked yet: the form says so
    await t.enterText(find.byType(TextField).at(0), 'Sara (front desk)');
    await t.enterText(find.byType(TextField).at(1), 'sara@example.com');
    await _scrollTo(t, find.text('Send invitation'));
    await _tapText(t, find.text('Send invitation'));
    await _pump(t, 500);
    expect(find.textContaining('Tick at least one'), findsOneWidget);
    // give her Edit on Testimonials
    await t.scrollUntilVisible(find.text('Testimonials'), -300, scrollable: find.byType(Scrollable).first);
    await _tapText(t, find.text('Edit').first);
    await _pump(t, 400);
    await _scrollTo(t, find.text('Send invitation'));
    await _tapText(t, find.text('Send invitation'));
    await _pump(t, 1500);
    await _scrollTo(t, find.textContaining('Your team'));
    expect(find.textContaining('Your team  1 of 10'), findsOneWidget);
    expect(find.text('Sara (front desk)'), findsWidgets);
    expect(find.textContaining('Edit: Testimonials'), findsOneWidget);
    await _finish(t);
  });

  test('the team keeps access per section, refuses duplicates and can remove people', () async {
    final w = MockWebRepo();
    final m = await w.inviteTeamMember(name: 'Sara', email: 'sara@example.com', access: {'testimonials': 'edit', 'gallery': 'view'}, method: 'invite');
    expect(m.access['testimonials'], 'edit');
    expect(() => w.inviteTeamMember(name: 'Sara again', email: 'SARA@example.com', access: {'gallery': 'view'}, method: 'invite'), throwsException);
    await w.updateTeamAccess(m.id, {'gallery': 'edit'});
    expect((await w.teamMembers()).single.access, {'gallery': 'edit'});
    await w.removeTeamMember(m.id);
    expect(await w.teamMembers(), isEmpty);
  });
}
