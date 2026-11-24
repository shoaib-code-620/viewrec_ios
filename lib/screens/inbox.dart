import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final shown = widget.leads.where((l) {
      final okTab = switch (tab) { 1 => _unread(l), 2 => l.status == 'won' || l.status == 'lost', _ => true };
      return okTab && (l.name.toLowerCase().contains(q.toLowerCase()) || l.message.toLowerCase().contains(q.toLowerCase()));
    }).toList();
    final unread = widget.leads.where(_unread).length;
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
      children: [
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
        ).reveal(context, 0),
        const SizedBox(height: 14),
        LiquidPills(['All', unread > 0 ? 'Unread ($unread)' : 'Unread', 'Closed'], tab, (i) => setState(() => tab = i)).reveal(context, 1),
        const SizedBox(height: 14),
        if (shown.isEmpty) const EmptyState(Icons.mark_chat_unread_rounded, 'No messages here', 'New conversations will appear here.'),
        for (var i = 0; i < shown.length; i++) _row(context, shown[i]).reveal(context, 2 + i, 0.08),
      ],
    );
  }

  Widget _row(BuildContext context, Lead l) {
    final unread = _unread(l);
    return Padding(
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
            if (unread) Positioned(right: -1, top: -1, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: C.rec, shape: BoxShape.circle, border: Border.all(color: C.surface, width: 2.5)))),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 15))),
                Text(l.when, style: TextStyle(fontSize: 11.5, color: unread ? C.primary : C.muted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Text(l.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.35, color: unread ? C.text : C.muted, fontWeight: unread ? FontWeight.w600 : FontWeight.w500)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.north_east_rounded, size: 12, color: C.primary),
                const SizedBox(width: 4),
                Flexible(child: Text('${l.service} · ${l.source}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.primary, fontWeight: FontWeight.w700))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
