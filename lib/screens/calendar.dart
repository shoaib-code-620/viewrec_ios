import 'package:flutter/material.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../shell.dart';
import '../widgets.dart';
import 'automations.dart';
import 'reminder_sheet.dart';

/// Phonebook calendar: a month of invitations, reminders, automations and group emails, sent and still to go.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int version = 0;

  static const _names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  Color _color(String k) => switch (k) { 'invite' => C.primary, 'reminder' => C.amber, 'bundle' => C.blue, _ => C.green };
  IconData _icon(String k) => switch (k) { 'invite' => Icons.send_rounded, 'reminder' => Icons.notifications_active_rounded, 'bundle' => Icons.groups_rounded, _ => Icons.bolt_rounded };
  Future<void> _setReminder() async {
    final today = DateTime.now();
    final isToday = selected.year == today.year && selected.month == today.month && selected.day == today.day;
    final saved = await showReminderSheet(context, date: isToday ? selected.add(const Duration(days: 1)) : selected);
    if (saved && mounted) setState(() => version++);
  }

  /// Group emails are scheduled on the Automations page, as on the website.
  void _toAutomations(BuildContext context) {
    final shell = context.findAncestorStateOfType<ShellState>();
    if (shell != null) {
      shell.goTo(5);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Scaffold(body: AutomationsScreen())));
    }
  }

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) => AsyncView<List<CalendarEvent>>(
        key: ValueKey((month, version)),
        load: () => webRepo.calendarEvents(month),
        skeletonCards: 3,
        builder: (context, events, refresh) {
          final first = DateTime(month.year, month.month, 1);
          final lead = first.weekday - 1; // Monday first
          final days = DateTime(month.year, month.month + 1, 0).day;
          final cells = lead + days;
          final rows = (cells / 7).ceil();
          final todays = events.where((e) => _same(e.date, selected)).toList();
          return AppPage(reveal: false, children: [
            AppCard(
              child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(child: Center(child: AnimatedSwitcher(duration: kFast, child: Text('${_names[month.month - 1]} ${month.year}', key: ValueKey(month), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))))),
                  IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.muted)))),
                ]),
                const SizedBox(height: 6),
                for (var r = 0; r < rows; r++)
                  Row(children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Builder(builder: (_) {
                          final n = r * 7 + c - lead + 1;
                          if (n < 1 || n > days) return const SizedBox(height: 46);
                          final day = DateTime(month.year, month.month, n);
                          final ev = events.where((e) => _same(e.date, day)).toList();
                          final isSel = _same(day, selected);
                          final isToday = _same(day, DateTime.now());
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => selected = day),
                            child: AnimatedContainer(
                              duration: kMed,
                              curve: kCurve,
                              height: 46,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSel ? C.primary : (isToday ? C.primarySoft : Colors.transparent),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isSel ? Colors.white : C.text)),
                                const SizedBox(height: 3),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  for (final e in ev.take(3)) Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? Colors.white : _color(e.kind))),
                                ]),
                              ]),
                            ),
                          );
                        }),
                      ),
                  ]),
              ]),
            ).reveal(context, 0),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final k in const [('invite', 'Invitations'), ('reminder', 'Reminders'), ('automation', 'Automations'), ('bundle', 'Group emails')])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _color(k.$1))),
                  const SizedBox(width: 6),
                  Text(k.$2, style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
                ]),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppButton('Set reminder', icon: Icons.notifications_active_rounded, small: true, onTap: _setReminder)),
              const SizedBox(width: 8),
              Expanded(child: AppButton('Email a group', icon: Icons.mail_outline_rounded, small: true, style: BtnStyle.ghost, onTap: () => _toAutomations(context))),
            ]),
            SectionHeader(_same(selected, DateTime.now()) ? 'Today' : '${selected.day} ${_names[selected.month - 1]}'),
            AnimatedSwitcher(
              duration: kMed,
              child: Column(key: ValueKey(selected), children: [
                if (todays.isEmpty) const EmptyState(Icons.event_available_rounded, 'Nothing scheduled', 'Pick another day to see what is going out.'),
                for (final e in todays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: _color(e.kind).withValues(alpha: 0.15)), child: Icon(_icon(e.kind), color: _color(e.kind), size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Muted(e.who, size: 12.5),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 80),
          ]);
        },
      );
}
