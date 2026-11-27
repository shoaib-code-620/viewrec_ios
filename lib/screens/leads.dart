import 'package:flutter/material.dart';
import '../async_view.dart';
import '../calls.dart';
import 'lead_thread.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../shell.dart';
import '../widgets.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<Lead>>(
        load: repo.leads,
        builder: (context, leads, refresh) => _LeadsBody(leads: leads, refresh: refresh),
      );
}

class _LeadsBody extends StatefulWidget {
  final List<Lead> leads;
  final Future<void> Function() refresh;
  const _LeadsBody({required this.leads, required this.refresh});
  @override
  State<_LeadsBody> createState() => _LeadsBodyState();
}

/// A status and how many requests are in it. The number counts up or down when it changes.
class _CountTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _CountTile({required this.label, required this.count, required this.color, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: kMed,
            curve: kCurve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: active ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
              color: active ? null : (C.dark ? C.surface : Colors.white.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? Colors.white.withValues(alpha: 0.4) : (C.dark ? C.border : Colors.white)),
              boxShadow: active ? [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : C.shadow,
            ),
            child: Column(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: count.toDouble(), end: count.toDouble()),
                duration: const Duration(milliseconds: 450),
                curve: kCurve,
                builder: (context, v, _) => Text('${v.round()}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: active ? Colors.white : C.text)),
              ),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Colors.white : color)),
                const SizedBox(width: 5),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white70 : C.muted)))),
              ]),
            ]),
          ),
        ),
      );
}

class _LeadsBodyState extends State<_LeadsBody> {
  late final List<Lead> leads = widget.leads;
  int tab = 0;
  bool dragging = false;
  static const tabs = ['All', 'New', 'Contacted', 'Won', 'Lost'];

  Color _c(String s) => switch (s) { 'new' => C.amber, 'contacted' => C.blue, 'won' => C.green, _ => C.muted };

  Future<void> _setStatus(Lead l, String s) async {
    final prev = l.status;
    setState(() => l.status = s);
    context.findAncestorStateOfType<ShellState>()?.refreshBadges();
    try {
      await repo.setLeadStatus(l.id, s);
    } catch (e) {
      if (mounted) {
        setState(() => l.status = prev);
        context.findAncestorStateOfType<ShellState>()?.refreshBadges();
        showMsg(context, "Couldn't update the lead. Try again.");
      }
    }
  }

  void _open(Lead l) => showSheet(
        context,
        StatefulBuilder(
          builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(l.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Muted('${l.service} · via ${l.source}', size: 13),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
              child: Text(l.message, style: const TextStyle(height: 1.45)),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppButton('Call', icon: Icons.call_rounded, small: true, onTap: () {
                Navigator.pop(ctx);
                callPhone(context, name: l.name, phone: l.phone, onCalled: () => repo.logLeadCall(l.id).catchError((_) => ThreadMessage(id: '', from: '', text: '', when: ''))); 
              })),
              const SizedBox(width: 8),
              Expanded(child: AppButton('Reply', icon: Icons.reply_rounded, small: true, style: BtnStyle.ghost, onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadThreadScreen(lead: l))).then((_) {
                  if (mounted) setState(() {});
                });
              })),
            ]),
            const SizedBox(height: 14),
            Text('Mark as', style: TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(runSpacing: 8, children: [
              for (final s in const ['new', 'contacted', 'won', 'lost'])
                AppChip(s[0].toUpperCase() + s.substring(1), active: l.status == s, onTap: () {
                  _setStatus(l, s);
                  set(() {});
                }),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shown = leads.where((l) => tab == 0 || l.status == tabs[tab].toLowerCase()).toList();
    return Stack(children: [
      RefreshIndicator(
      onRefresh: widget.refresh,
      child: AppPage(children: [
        const Muted('Requests from your directory listing, review page and website. Reply fast to win the job. Hold a request and drag it to a status at the top to move it.'),
        const SizedBox(height: 14),
        // One count for every status, so moving a request to any of them shows at once. Tap one to filter.
        Row(children: [
          for (var i = 1; i < tabs.length; i++)
            _CountTile(
              label: tabs[i],
              count: leads.where((l) => l.status == tabs[i].toLowerCase()).length,
              color: _c(tabs[i].toLowerCase()),
              active: tab == i,
              onTap: () => setState(() => tab = tab == i ? 0 : i),
            ),
        ]),
        const SizedBox(height: 16),
        Pills(tabs, tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 12),
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DragCard<Lead>(
              data: l,
              onStart: () => setState(() => dragging = true),
              onEnd: () => setState(() => dragging = false),
              child: AppCard(
              onTap: () => _open(l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(l.name, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Muted('${l.service} · ${l.when}', size: 12.5),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: _c(l.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: PopOnChange(value: l.status, child: Text(l.status[0].toUpperCase() + l.status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _c(l.status)))),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(l.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 14, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [Icon(Icons.north_east_rounded, size: 13, color: C.primary), const SizedBox(width: 4), Text('via ${l.source}', style: TextStyle(fontSize: 12, color: C.primary))]),
              ]),
            ),
            ),
          ),
        if (shown.isEmpty) const EmptyState(Icons.handshake_rounded, 'No requests here', 'People who ask for your work show up here as soon as they get in touch.'),
        const SizedBox(height: 80),
      ]),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: DropZoneBar<Lead>(
          show: dragging,
          zones: [
            DropZone('new', 'New', C.amber, Icons.mark_email_unread_rounded),
            DropZone('contacted', 'Contacted', C.blue, Icons.reply_rounded),
            DropZone('won', 'Won', C.green, Icons.emoji_events_rounded),
            DropZone('lost', 'Lost', C.muted, Icons.close_rounded),
          ],
          canDrop: (l, id) => l.status != id,
          onDrop: (l, id) {
            _setStatus(l, id);
            if (id == 'won') {
              showSuccess(context, 'Marked as won: ${l.name}');
            } else {
              showMsg(context, '${l.name} marked as $id');
            }
          },
        ),
      ),
    ]);
  }
}
