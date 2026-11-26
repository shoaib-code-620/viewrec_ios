import 'package:flutter/material.dart';
import '../async_view.dart';
import '../entitlement.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'reminder_sheet.dart';

typedef _Data = (List<CalendarEvent>, List<Bundle>, Entitlement);

/// Automations > Scheduled: remind yourself, email a group on a day, what is lined up, and what has run.
class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({super.key});
  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

class _ScheduledScreenState extends State<ScheduledScreen> {
  int version = 0;

  Future<_Data> _load() async {
    final now = DateTime.now();
    final r = await Future.wait<Object>([
      webRepo.calendarEvents(DateTime(now.year, now.month)),
      webRepo.calendarEvents(DateTime(now.year, now.month + 1)),
      webRepo.bundles(),
      loadEntitlement(),
    ]);
    return ([...(r[0] as List<CalendarEvent>), ...(r[1] as List<CalendarEvent>)], r[2] as List<Bundle>, r[3] as Entitlement);
  }

  @override
  Widget build(BuildContext context) => AsyncView<_Data>(
        key: ValueKey(version),
        load: _load,
        skeletonCards: 3,
        builder: (context, d, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(data: d, changed: () => setState(() => version++))),
      );
}

class _Body extends StatefulWidget {
  final _Data data;
  final VoidCallback changed;
  const _Body({required this.data, required this.changed});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  List<CalendarEvent> get events => widget.data.$1;
  List<Bundle> get bundles => widget.data.$2;
  Entitlement get ent => widget.data.$3;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _remind() async {
    if (await showReminderSheet(context)) widget.changed();
  }

  Future<void> _email() async {
    if (!ent.allows('contact_bundles')) {
      showUpgrade(context, ent, 'contact_bundles', 'Groups');
      return;
    }
    if (bundles.isEmpty) {
      showMsg(context, 'Make a group first, in Business Phonebook');
      return;
    }
    var picked = bundles.first;
    var on = _today.add(const Duration(days: 1));
    final subject = TextEditingController(), body = TextEditingController();
    String? error;
    var saving = false;
    final saved = await showSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: H2('Schedule an email')),
            IconButton(onPressed: () => Navigator.pop(ctx, false), icon: Icon(Icons.close_rounded, color: C.muted)),
          ]),
          const Muted('Goes to everyone in the group on the day you choose. No review link, and anyone who opted out is skipped.', size: 13),
          const SizedBox(height: 12),
          const Text('Group', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(children: [for (final b in bundles) AppChip('${b.name} (${b.memberIds.length})', active: picked.id == b.id, onTap: () => set(() => picked = b))]),
          const SizedBox(height: 8),
          const Text('Send on', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(context: ctx, initialDate: on, firstDate: _today, lastDate: DateTime(_today.year + 2));
              if (p != null) set(() => on = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rMd), border: Border.all(color: C.border)),
              child: Row(children: [Expanded(child: Text(formatDate(on), style: const TextStyle(fontSize: 16))), Icon(Icons.calendar_today_rounded, size: 20, color: C.muted)]),
            ),
          ),
          const SizedBox(height: 14),
          Field('Subject', controller: subject, hint: 'A little something for our best customers'),
          Field('Message', controller: body, lines: 5, hint: 'Hi, thank you again for choosing us...'),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
          Row(children: [
            Expanded(
              flex: 2,
              child: AppButton(saving ? 'Saving…' : 'Schedule email', icon: Icons.schedule_send_rounded, loading: saving, onTap: saving
                  ? null
                  : () async {
                      if (subject.text.trim().isEmpty || body.text.trim().length < 10) return set(() => error = 'Add a subject and a message');
                      set(() {
                        error = null;
                        saving = true;
                      });
                      try {
                        await webRepo.scheduleGroupEmail(bundleId: picked.id, date: on, subject: subject.text.trim(), body: body.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (_) {
                        set(() {
                          saving = false;
                          error = "Couldn't schedule it. Try again.";
                        });
                      }
                    }),
            ),
            const SizedBox(width: 10),
            Expanded(child: AppButton('Cancel', style: BtnStyle.ghost, onTap: () => Navigator.pop(ctx, false))),
          ]),
        ]),
      ),
    );
    if (saved == true) {
      if (mounted) showSuccess(context, 'Email scheduled for ${formatDate(on)}');
      widget.changed();
    }
  }

  Future<void> _cancel(CalendarEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Cancel this?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(e.title, style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep it', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Cancel it', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await webRepo.cancelScheduled(e.id);
      widget.changed();
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't cancel it. Try again.");
    }
  }

  Widget _card(IconData icon, Color color, String title, String text, String button, VoidCallback onTap) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GlossIcon(icon, color, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Muted(text, size: 13),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          AppButton(button, icon: Icons.add_rounded, small: true, onTap: onTap),
        ]),
      );

  IconData _icon(String k) => switch (k) { 'reminder' => Icons.notifications_active_rounded, 'bundle' => Icons.groups_rounded, 'invite' => Icons.send_rounded, _ => Icons.bolt_rounded };

  String _when(DateTime d) {
    final diff = d.difference(_today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return formatDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = events.where((e) => !e.date.isBefore(_today) && (e.kind == 'reminder' || e.kind == 'bundle')).toList()..sort((a, b) => a.date.compareTo(b.date));
    final history = events.where((e) => e.date.isBefore(_today)).toList()..sort((a, b) => b.date.compareTo(a.date));
    return AppPage(reveal: false, children: [
      _card(Icons.alarm_rounded, const Color(0xFFF2A100), 'Remind me', 'A note to yourself in the bell, on a day you choose. Nothing is emailed to anybody.', 'Set a reminder', _remind),
      const SizedBox(height: 14),
      _card(Icons.mail_outline_rounded, C.primary, 'Email a group', 'Sends what you write to everyone in a group, on a day you choose. No review link, and anyone who unsubscribed is skipped.', 'Schedule an email', _email),
      const SectionHeader('Scheduled'),
      if (upcoming.isEmpty)
        const EmptyState(Icons.event_available_rounded, 'Nothing scheduled yet', 'Set a reminder or schedule a group email and it will show here.')
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < upcoming.length; i++)
              Tile(
                icon: _icon(upcoming[i].kind),
                iconColor: upcoming[i].kind == 'bundle' ? C.blue : C.amber,
                title: upcoming[i].title,
                subtitle: '${_when(upcoming[i].date)} · ${upcoming[i].who}',
                divider: i < upcoming.length - 1,
                trailing: upcoming[i].mine ? IconButton(tooltip: 'Cancel', onPressed: () => _cancel(upcoming[i]), icon: Icon(Icons.close_rounded, size: 20, color: C.muted)) : null,
              ),
          ]),
        ),
      const SectionHeader('Run history'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: C.green)),
            const SizedBox(width: 8),
            Expanded(child: Muted('Checks every 5 minutes · last 3 min ago', size: 12.5)),
          ]),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Muted('Nothing has run yet. Each run appears here with what it did.', size: 13)
          else
            for (final e in history.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Icon(_icon(e.kind), size: 18, color: C.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${e.title}${e.who.isEmpty ? '' : ' · ${e.who}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                  const SizedBox(width: 8),
                  Text(formatDate(e.date), style: TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
        ]),
      ),
      const SizedBox(height: 120),
    ]);
  }
}
