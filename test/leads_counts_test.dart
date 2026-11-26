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

/// The number on the tile with this label.
String _count(WidgetTester t, String label) {
  final tile = find.ancestor(of: find.text(label).first, matching: find.byType(Column)).first;
  final texts = t.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text))).map((w) => w.data ?? '').toList();
  return texts.firstWhere((s) => int.tryParse(s) != null, orElse: () => '?');
}

void main() {
  testWidgets('Leads shows a count for every status and they change when a request is dragged to another status', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 4)));
    await _pump(t, 3000);
    for (final s in const ['New', 'Contacted', 'Won', 'Lost']) {
      expect(find.text(s), findsWidgets, reason: 'a tile for $s');
    }
    final newBefore = int.parse(_count(t, 'New'));
    final contactedBefore = int.parse(_count(t, 'Contacted'));
    // press and hold the first request, drop it on Contacted
    final card = find.text('Rebecca Shaw').first;
    final g = await t.startGesture(t.getCenter(card));
    await _pump(t, 500);
    final zone = find.text('Contacted').last;
    final start = t.getCenter(card), target = t.getCenter(zone);
    for (var s = 1; s <= 6; s++) {
      await g.moveTo(Offset.lerp(start, target, s / 6)!);
      await t.pump(const Duration(milliseconds: 60));
    }
    await g.up();
    await _pump(t, 1500);
    expect(int.parse(_count(t, 'New')), newBefore - 1, reason: 'New went down');
    expect(int.parse(_count(t, 'Contacted')), contactedBefore + 1, reason: 'Contacted went up');
    await _pump(t, 6000);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
