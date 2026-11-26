import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewrec/order_store.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';
import 'package:viewrec/widgets.dart';

Future<void> _phone(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  C.dark = false;
  SharedPreferences.setMockInitialValues({});
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

/// Press and hold [from], drag it onto [to], let go.
Future<void> _drag(WidgetTester t, Finder from, Finder to) async {
  final g = await t.startGesture(t.getCenter(from));
  await t.pump(const Duration(milliseconds: 400));
  final target = t.getCenter(to);
  final start = t.getCenter(from);
  for (var s = 1; s <= 6; s++) {
    await g.moveTo(Offset.lerp(start, target, s / 6)!);
    await t.pump(const Duration(milliseconds: 50));
  }
  await g.up();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  test('order helpers: saved order wins, new items go last, gone items drop out', () {
    expect(applyOrder(['a', 'b', 'c'], ['c', 'a'], (s) => s), ['c', 'a', 'b']);
    expect(applyOrder(['a', 'b'], ['x', 'b', 'a'], (s) => s), ['b', 'a']);
    expect(applyOrder(['a', 'b'], null, (s) => s), ['a', 'b']);
    expect(movedBefore(['a', 'b', 'c', 'd'], 'a', 'c'), ['b', 'c', 'a', 'd'], reason: 'dragging down lands after the target');
    expect(movedBefore(['a', 'b', 'c', 'd'], 'd', 'b'), ['a', 'd', 'b', 'c'], reason: 'dragging up lands before the target');
    expect(movedBefore(['a', 'b'], 'a', 'a'), ['a', 'b']);
  });

  testWidgets('the undo message goes away by itself, and Undo works', (t) async {
    await _phone(t);
    var undone = 0;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(dark: false),
      home: Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => showUndo(c, 'Rebecca Shaw closed', () => undone++), child: const Text('go'))))),
    ));
    await t.tap(find.text('go'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Rebecca Shaw closed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.text('Rebecca Shaw closed'), findsNothing, reason: 'it must fade away without being tapped');
    await t.tap(find.text('go'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('Undo'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(undone, 1);
    expect(find.text('Rebecca Shaw closed'), findsNothing);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('More: press and hold a tile and drop it on another to move it, and Reset order puts it back', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: kMoreIndex)));
    await _settle(t);
    final gallery = find.text('Gallery').first;
    final first = find.text('Create your posting').first;
    expect(t.getTopLeft(first).dx < t.getTopLeft(gallery).dx, isTrue, reason: 'Create your posting starts first');
    expect(find.text('Press and hold to move'), findsWidgets);
    await _drag(t, gallery, first);
    await _settle(t);
    expect(t.getTopLeft(gallery).dx < t.getTopLeft(first).dx, isTrue, reason: 'Gallery now comes first');
    expect(find.text('Reset order'), findsOneWidget);
    expect((await OrderStore.load('more_menu'))!.first, '15', reason: 'the new order is remembered');
    await t.tap(find.text('Reset order'));
    await _settle(t);
    expect(t.getTopLeft(first).dx < t.getTopLeft(gallery).dx, isTrue);
    expect(await OrderStore.load('more_menu'), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets('Business Phonebook tabs can be rearranged, like the website', (t) async {
    await _phone(t);
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 3)));
    await _settle(t);
    final calendar = find.text('Groups').first;
    final customers = find.text('Your customers').first;
    expect(t.getTopLeft(customers).dx < t.getTopLeft(calendar).dx, isTrue);
    await _drag(t, calendar, customers);
    await _settle(t);
    expect(t.getTopLeft(calendar).dx < t.getTopLeft(customers).dx, isTrue, reason: 'Groups was moved to the front');
    expect((await OrderStore.load('phonebook_tabs'))!.first, 'Groups');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
