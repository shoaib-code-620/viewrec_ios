import 'package:flutter/material.dart';
import '../async_view.dart';
import '../data.dart';
import '../entitlement.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// What a group is for: an offer to people who already bought, or a first approach to people who have not.
class GroupPurposePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const GroupPurposePicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const options = [
      ('offer', 'An offer for past customers', 'A discount or a thank-you to people who have already bought from you.'),
      ('approach', 'A first approach', 'An introduction to people who have not bought from you yet.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('What is it for?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            onTap: () => onChanged(o.$1),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: value == o.$1 ? C.primary.withValues(alpha: 0.1) : C.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: value == o.$1 ? C.primary : C.border, width: value == o.$1 ? 1.6 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.$2, style: TextStyle(fontWeight: FontWeight.w700, color: value == o.$1 ? C.primary : C.text)),
                const SizedBox(height: 2),
                Muted(o.$3, size: 13),
              ]),
            ),
          ),
        ),
      if (value == 'offer') const Padding(padding: EdgeInsets.only(bottom: 8), child: Muted('Everybody in this group has bought from you before. That is what makes it an offer rather than an approach.', size: 12.5)),
    ]);
  }
}

/// Asks for a group's name, what it is for and an optional note. Returns null if cancelled.
Future<({String name, String purpose, String note})?> askGroupDetails(BuildContext context, {String name = '', String purpose = 'offer', String note = '', String button = 'Make the group'}) async {
  final n = TextEditingController(text: name), t = TextEditingController(text: note);
  var p = purpose;
  String? error;
  final r = await showSheet<(String, String, String)>(
    context,
    StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: H2('New group')),
          IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, color: C.muted)),
        ]),
        const Muted('Name it for yourself. Your customers never see it.', size: 13),
        const SizedBox(height: 10),
        Field('Name', controller: n, hint: 'Spring kitchens'),
        GroupPurposePicker(value: p, onChanged: (v) => set(() => p = v)),
        Field('Note (optional)', controller: t, lines: 2, hint: 'Everybody whose kitchen we did between March and May.'),
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
        AppButton(button, onTap: () {
          if (n.text.trim().isEmpty) return set(() => error = 'Give the group a name');
          Navigator.pop(ctx, (n.text.trim(), p, t.text.trim()));
        }),
      ]),
    ),
  );
  return r == null ? null : (name: r.$1, purpose: r.$2, note: r.$3);
}

/// Groups of customers that get one message together. Pro and up.
class BundlesScreen extends StatelessWidget {
  const BundlesScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<(List<Bundle>, List<Customer>, Entitlement)>(
        load: () async => (await webRepo.bundles(), await repo.customers(), await loadEntitlement()),
        builder: (context, d, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _BundlesBody(bundles: d.$1, customers: d.$2, ent: d.$3)),
      );
}

class _BundlesBody extends StatefulWidget {
  final List<Bundle> bundles;
  final List<Customer> customers;
  final Entitlement ent;
  const _BundlesBody({required this.bundles, required this.customers, required this.ent});
  @override
  State<_BundlesBody> createState() => _BundlesBodyState();
}

class _BundlesBodyState extends State<_BundlesBody> {
  late final bundles = List.of(widget.bundles);
  bool get _allowed => widget.ent.allows('contact_bundles');

  void _gate(VoidCallback go) {
    if (!_allowed) {
      showUpgrade(context, widget.ent, 'contact_bundles', 'Groups');
      return;
    }
    go();
  }

  void _edit([Bundle? b]) => _gate(() {
        final name = TextEditingController(text: b?.name ?? '');
        final note = TextEditingController(text: b?.note ?? '');
        var purpose = b?.purpose ?? 'offer';
        final picked = <String>{...?b?.memberIds};
        showSheet(
          context,
          StatefulBuilder(
            builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              H2(b == null ? 'New group' : 'Edit group'),
              const SizedBox(height: 14),
              Field('Name', controller: name, hint: 'Spring kitchens'),
              GroupPurposePicker(value: purpose, onChanged: (v) => set(() => purpose = v)),
              Field('Note (optional)', controller: note, lines: 2, hint: 'Everybody whose kitchen we did between March and May.'),
              Row(children: [
                const Expanded(child: Text('Customers', style: TextStyle(fontWeight: FontWeight.w800))),
                Text('${picked.length} picked', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: picked.isNotEmpty ? C.green : C.muted)),
              ]),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.34),
                child: ListView(shrinkWrap: true, children: [
                  for (final c in widget.customers)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: C.primary,
                      value: picked.contains(c.id),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(c.job, style: TextStyle(color: C.muted, fontSize: 12)),
                      onChanged: (v) => set(() => v == true ? picked.add(c.id) : picked.remove(c.id)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              AppButton(b == null ? 'Make the group' : 'Save changes', small: true, onTap: () async {
                if (name.text.trim().isEmpty) {
                  showMsg(context, 'Give the group a name.');
                  return;
                }
                if (picked.isEmpty) {
                  showMsg(context, 'Pick at least one customer.');
                  return;
                }
                Navigator.pop(ctx);
                final saved = await webRepo.saveBundle(id: b?.id, name: name.text.trim(), memberIds: picked.toList(), purpose: purpose, note: note.text.trim());
                if (!mounted) return;
                setState(() {
                  final i = bundles.indexWhere((x) => x.id == saved.id);
                  if (i >= 0) {
                    bundles[i] = saved;
                  } else {
                    bundles.insert(0, saved);
                  }
                });
              }),
            ]),
          ),
        );
      });

  void _send(Bundle b) => _gate(() {
        final subject = TextEditingController(), body = TextEditingController();
        showSheet(
          context,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2('Email ${b.name}'),
            const SizedBox(height: 4),
            Muted('One message to ${b.memberIds.length} people. Anyone who opted out is skipped.', size: 13),
            const SizedBox(height: 14),
            Field('Subject', controller: subject, hint: 'Could you share a few words?'),
            Field('Message', controller: body, lines: 5, hint: 'Hi, thanks again for choosing us...'),
            AppButton('Send to group', icon: Icons.send_rounded, small: true, onTap: () async {
              if (subject.text.trim().isEmpty || body.text.trim().length < 10) {
                showMsg(context, 'Add a subject and a message.');
                return;
              }
              Navigator.pop(context);
              try {
                await webRepo.sendBundle(b.id, subject: subject.text.trim(), body: body.text.trim());
                if (mounted) {
                  setState(() => b.lastSent = 'just now');
                  showSuccess(context, 'Sent to ${b.memberIds.length} people');
                }
              } catch (e) {
                if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
              }
            }),
          ]),
        );
      });

  Future<void> _delete(Bundle b) async {
    setState(() => bundles.remove(b));
    try {
      await webRepo.deleteBundle(b.id);
    } catch (_) {
      if (mounted) setState(() => bundles.insert(0, b));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        const Muted('Put customers in a group and write to all of them at once. A group email goes through the same opt-out and quiet-hours checks as an invitation.').reveal(context, 0),
        if (!_allowed) ...[
          const SizedBox(height: 12),
          const InfoBanner('Groups are a Pro feature. You can look around, but creating and sending needs Pro or above.', icon: Icons.lock_rounded).reveal(context, 1),
        ],
        const SizedBox(height: 14),
        AppButton('Create group', icon: Icons.group_add_rounded, small: true, onTap: _edit).reveal(context, 2),
        const SizedBox(height: 14),
        if (bundles.isEmpty) const EmptyState(Icons.groups_rounded, 'No groups yet', 'Make a group to email several customers at once.'),
        for (var i = 0; i < bundles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => _edit(bundles[i]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: C.primarySoft), child: Icon(Icons.groups_rounded, color: C.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bundles[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Muted('${bundles[i].memberIds.length} people · ${bundles[i].purposeLabel} · ${bundles[i].lastSent}', size: 12.5),
                    ]),
                  ),
                  IconButton(onPressed: () => _delete(bundles[i]), icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20), visualDensity: VisualDensity.compact),
                ]),
                const SizedBox(height: 12),
                AppButton('Email this group', icon: Icons.mail_rounded, small: true, style: BtnStyle.ghost, onTap: () => _send(bundles[i])),
              ]),
            ),
          ).reveal(context, 3 + i, 0.08),
        const SizedBox(height: 80),
      ]);
}
