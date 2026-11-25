import 'package:flutter/material.dart';
import '../async_view.dart';
import '../data.dart';
import '../entitlement.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Contact bundles: groups of 10 to 20 customers that get one message together. Pro and up.
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
      showUpgrade(context, widget.ent, 'contact_bundles', 'Contact bundles');
      return;
    }
    go();
  }

  void _edit([Bundle? b]) => _gate(() {
        final name = TextEditingController(text: b?.name ?? '');
        final picked = <String>{...?b?.memberIds};
        showSheet(
          context,
          StatefulBuilder(
            builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              H2(b == null ? 'New bundle' : 'Edit bundle'),
              const SizedBox(height: 14),
              Field('Name', controller: name, hint: 'Roof replacements 2026'),
              Row(children: [
                const Expanded(child: Text('Customers', style: TextStyle(fontWeight: FontWeight.w800))),
                Text('${picked.length} picked · 10 to 20', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: picked.length >= 10 && picked.length <= 20 ? C.green : C.muted)),
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
              AppButton('Save bundle', small: true, onTap: () async {
                if (name.text.trim().isEmpty) {
                  showMsg(context, 'Give the bundle a name.');
                  return;
                }
                if (picked.length < 10 || picked.length > 20) {
                  showMsg(context, 'A bundle needs 10 to 20 customers. You picked ${picked.length}.');
                  return;
                }
                Navigator.pop(ctx);
                final saved = await webRepo.saveBundle(id: b?.id, name: name.text.trim(), memberIds: picked.toList());
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
        const Muted('Group 10 to 20 customers and send them one message together. A group email goes through the same opt-out and quiet-hours checks as an invitation.').reveal(context, 0),
        if (!_allowed) ...[
          const SizedBox(height: 12),
          const InfoBanner('Contact bundles are a Pro feature. You can look around, but creating and sending needs Pro or above.', icon: Icons.lock_rounded).reveal(context, 1),
        ],
        const SizedBox(height: 14),
        AppButton('New bundle', icon: Icons.group_add_rounded, small: true, onTap: _edit).reveal(context, 2),
        const SizedBox(height: 14),
        if (bundles.isEmpty) const EmptyState(Icons.groups_rounded, 'No bundles yet', 'Make a group to email several customers at once.'),
        for (var i = 0; i < bundles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => _edit(bundles[i]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: C.primarySoft), child: Icon(Icons.groups_rounded, color: C.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bundles[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Muted('${bundles[i].memberIds.length} people · ${bundles[i].lastSent}', size: 12.5),
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
