import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewrec/screens/support_chat.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(seconds: 2));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Support is a full screen: no tab bar, and the emoji button opens the picker', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const SupportScreen()));
    await _settle(t);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Reviews'), findsNothing, reason: 'the tab bar must not show');
    expect(find.byType(EmojiPicker), findsNothing);
    await t.tap(find.byTooltip('Add an emoji'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(EmojiPicker), findsOneWidget);
    await t.tap(find.byTooltip('Show keyboard'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(EmojiPicker), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets('Calendar has Set reminder and Email a group, and Email a group opens Automations', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    C.dark = false;
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: false), home: const Shell(initialIndex: 17)));
    await _settle(t);
    expect(find.text('Set reminder'), findsOneWidget);
    expect(find.text('Email a group'), findsOneWidget);
    await t.ensureVisible(find.text('Email a group'));
    await t.tap(find.text('Email a group'));
    await _settle(t);
    await _settle(t);
    expect(find.text('Automations'), findsWidgets);
    expect(find.text('Set a reminder'), findsOneWidget, reason: 'now on the Automations page, which has the reminder card');
    await t.pump(const Duration(seconds: 6));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
