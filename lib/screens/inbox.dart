import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lead_thread.dart';

/// Inbox: conversations with customers and people asking for your work.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(18, 10, 18, 0), child: BackHeader('Inbox')),
            Expanded(
              child: AsyncView<List<Lead>>(
                load: repo.leads,
                builder: (context, leads, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _InboxBody(leads: leads)),
              ),
            ),
          ]),
        ),
      );
}

class _InboxBody extends StatefulWidget {
  final List<Lead> leads;
  const _InboxBody({required this.leads});
  @override
  State<_InboxBody> createState() => _InboxBodyState();
}

class _InboxBodyState extends State<_InboxBody> {
  int tab = 0; // All, Unread, Closed
  String q = '';

  bool _unread(Lead l) => l.status == 'new';

  bool _matches(Lead l, String status) {
    final okTab = switch (tab) { 1 => status == 'new', 2 => status == 'won' || status == 'lost', _ => true };
    final ql = q.toLowerCase();
    return okTab && (l.name.toLowerCase().contains(ql) || l.message.toLowerCase().contains(ql) || (l.lastNote ?? '').toLowerCase().contains(ql));
  }

  Future<void> _setStatus(Lead l, String s) async {
    final prev = l.status;
    setState(() => l.status = s);
    try {
      await repo.setLeadStatus(l.id, s);
    } catch (_) {
      if (mounted) {
        setState(() => l.status = prev);
        showMsg(context, "Couldn't update ${l.name}. Try again.");
      }
    }
  }

  Future<void> _markAllRead() async {
    HapticFeedback.mediumImpact();
    final fresh = widget.leads.where(_unread).toList();
    for (final l in fresh) {
      await _setStatus(l, 'contacted');
    }
    if (mounted) showMsg(context, 'All caught up');
  }

  /// The status a swipe would give: right toggles read, left closes.
  String _swipeStatus(Lead l, bool toRight) => toRight ? (l.status == 'new' ? 'contacted' : 'new') : 'lost';

  void _applySwipe(Lead l, bool toRight) {
    final prev = l.status;
    final next = _swipeStatus(l, toRight);
    _setStatus(l, next);
    if (!toRight) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${l.name} closed'),
          action: SnackBarAction(label: 'Undo', textColor: const Color(0xFFB8A6FF), onPressed: () => _setStatus(l, prev)),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.leads.where((l) => _matches(l, l.status)).toList()
      ..sort((a, b) => (_unread(b) ? 1 : 0) - (_unread(a) ? 1 : 0)); // unread first
    final unread = widget.leads.where(_unread).length;
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
      children: [
        _summary(unread).reveal(context, 0),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'Search messages',
            hintStyle: TextStyle(color: C.muted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: C.muted),
            filled: true,
            fillColor: C.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
          ),
        ).reveal(context, 1),
        const SizedBox(height: 14),
        LiquidPills(['All', unread > 0 ? 'Unread ($unread)' : 'Unread', 'Closed'], tab, (i) => setState(() => tab = i)).reveal(context, 2),
        const SizedBox(height: 10),
        if (shown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(children: [
              Icon(Icons.swipe_rounded, size: 14, color: C.muted),
              const SizedBox(width: 6),
              Muted('Swipe right to mark read, left to close', size: 11.5),
            ]),
          ).reveal(context, 3),
        if (shown.isEmpty) const EmptyState(Icons.mark_chat_unread_rounded, 'No messages here', 'New conversations will appear here.'),
        for (var i = 0; i < shown.length; i++) _row(context, shown[i]).reveal(context, 4 + i, 0.08),
      ],
    );
  }

  Widget _summary(int unread) => AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: unread > 0 ? C.rec.withValues(alpha: 0.14) : C.green.withValues(alpha: 0.14)),
            child: Icon(unread > 0 ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded, color: unread > 0 ? C.rec : C.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PopOnChange(value: unread, child: Text(unread > 0 ? '$unread unread' : 'All caught up', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2))),
              const SizedBox(height: 2),
              Muted('${widget.leads.length} conversations', size: 12.5),
            ]),
          ),
          if (unread > 0) SizedBox(width: 108, child: AppButton('Read all', small: true, style: BtnStyle.ghost, onTap: _markAllRead)),
        ]),
      );

  Widget _swipeBg({required Alignment align, required Color color, required IconData icon, required String label}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: align,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(rLg)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ]),
      );

  Widget _row(BuildContext context, Lead l) {
    final unread = _unread(l);
    final note = l.lastNote ?? l.message;
    final isAttachment = (l.lastNote ?? '').contains('Voice note') || (l.lastNote ?? '').endsWith('Photo') || ((l.lastNote ?? '').startsWith('You: ') && (l.lastNote ?? '').contains('.'));
    final voice = (l.lastNote ?? '').contains('Voice note');
    return Dismissible(
      key: ValueKey('lead-${l.id}'),
      background: _swipeBg(align: Alignment.centerLeft, color: C.primary, icon: unread ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded, label: unread ? 'Read' : 'Unread'),
      secondaryBackground: _swipeBg(align: Alignment.centerRight, color: C.muted, icon: Icons.archive_rounded, label: 'Close'),
      confirmDismiss: (dir) async {
        final toRight = dir == DismissDirection.startToEnd;
        final willLeave = !_matches(l, _swipeStatus(l, toRight));
        if (!willLeave) {
          HapticFeedback.selectionClick();
          _applySwipe(l, toRight);
        }
        return willLeave;
      },
      onDismissed: (dir) {
        HapticFeedback.mediumImpact();
        _applySwipe(l, dir == DismissDirection.startToEnd);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadThreadScreen(lead: l)));
            if (mounted) setState(() {});
          },
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Avatar(l.name, size: 50),
              if (unread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(width: 14, height: 14, decoration: BoxDecoration(color: C.rec, shape: BoxShape.circle, border: Border.all(color: C.surface, width: 2.5))),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 15))),
                  Text(l.when, style: TextStyle(fontSize: 11.5, color: unread ? C.primary : C.muted, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (isAttachment) ...[Icon(voice ? Icons.mic_rounded : Icons.attach_file_rounded, size: 14, color: C.muted), const SizedBox(width: 4)],
                  Expanded(
                    child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.35, color: unread ? C.text : C.muted, fontWeight: unread ? FontWeight.w600 : FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  Icon(Icons.north_east_rounded, size: 12, color: C.primary),
                  const SizedBox(width: 4),
                  Flexible(child: Text('${l.service} · ${l.source}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.primary, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  StatusBadge(l.status),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
