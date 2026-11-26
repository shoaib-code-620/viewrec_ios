import 'package:flutter/material.dart';
import '../async_view.dart';
import '../data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contact_detail.dart';

/// Invitations sent: everyone who has been asked for a video, how long ago, how many reminders went out, and where they are now.
class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<Customer>>(
        load: repo.customers,
        builder: (context, list, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _InvitationsBody(all: list)),
      );
}

class _InvitationsBody extends StatefulWidget {
  final List<Customer> all;
  const _InvitationsBody({required this.all});
  @override
  State<_InvitationsBody> createState() => _InvitationsBodyState();
}

class _InvitationsBodyState extends State<_InvitationsBody> {
  int seg = 0; // 0 all, 1 waiting, 2 recorded
  final busy = <String>{};

  List<Customer> get sent => widget.all.where((c) => c.status == 'invited' || c.status == 'recorded').toList();

  Future<void> _remind(Customer c) async {
    if (busy.contains(c.id)) return;
    setState(() => busy.add(c.id));
    try {
      final n = await repo.remindCustomer(c.id);
      if (!mounted) return;
      setState(() => c.nudges = n);
      showMsg(context, 'Reminder sent to ${c.name}');
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy.remove(c.id));
    }
  }

  String _line(Customer c) {
    final parts = <String>[
      if (c.sentOn.isNotEmpty) 'Sent ${c.sentOn}' else 'Sent',
      if (c.nudges > 0) '${c.nudges} ${c.nudges == 1 ? 'reminder' : 'reminders'}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final all = sent;
    final shown = all.where((c) => seg == 0 || (seg == 1 ? c.status == 'invited' : c.status == 'recorded')).toList();
    final waiting = all.where((c) => c.status == 'invited').length;
    final recorded = all.where((c) => c.status == 'recorded').length;
    return AppPage(reveal: false, hPad: 0, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          _count('${all.length}', 'Invitations sent'),
          const SizedBox(width: 10),
          _count('$waiting', 'Waiting'),
          const SizedBox(width: 10),
          _count('$recorded', 'Recorded'),
        ]),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.only(left: 18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            AppChip('All', active: seg == 0, onTap: () => setState(() => seg = 0)),
            AppChip('Waiting', active: seg == 1, onTap: () => setState(() => seg = 1)),
            AppChip('Recorded', active: seg == 2, onTap: () => setState(() => seg = 2)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: EmptyState(Icons.mark_email_unread_outlined, all.isEmpty ? 'No invitations sent yet' : 'Nothing in this list', all.isEmpty ? 'Invite people from Your customers and they will show here.' : 'Try another filter.'),
        )
      else
        for (var i = 0; i < shown.length; i++) _row(shown[i], last: i == shown.length - 1),
      const SizedBox(height: 120),
    ]);
  }

  Widget _count(String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.dark ? C.surface : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.dark ? C.border : Colors.white),
            boxShadow: C.shadow,
          ),
          child: Column(children: [
            Text(n, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.muted))),
          ]),
        ),
      );

  Widget _row(Customer c, {required bool last}) {
    final canRemind = c.status == 'invited';
    return Pressable(
      scale: 0.99,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactDetailScreen(customer: c))).then((_) {
        if (mounted) setState(() {});
      }),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: C.border.withValues(alpha: 0.8)))),
        child: Row(children: [
          Avatar(c.name, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 1),
              Muted(_line(c), size: 13, maxLines: 1),
            ]),
          ),
          const SizedBox(width: 8),
          if (canRemind)
            IntrinsicWidth(child: AppButton('Remind', small: true, style: BtnStyle.ghost, loading: busy.contains(c.id), onTap: () => _remind(c)))
          else
            StatusBadge(c.status),
        ]),
      ),
    );
  }
}
