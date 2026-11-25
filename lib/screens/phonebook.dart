import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'import.dart';
import 'contact_detail.dart';

/// Business Phonebook, laid out like a phone's contact directory:
/// A-Z sections, swipe right to edit, swipe left to remove, tick people to make a group.
class PhonebookScreen extends StatelessWidget {
  const PhonebookScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<Customer>>(
        load: repo.customers,
        builder: (context, list, refresh) => _PhonebookBody(initial: list, refresh: refresh),
      );
}

class _PhonebookBody extends StatefulWidget {
  final List<Customer> initial;
  final Future<void> Function() refresh;
  const _PhonebookBody({required this.initial, required this.refresh});
  @override
  State<_PhonebookBody> createState() => _PhonebookBodyState();
}

enum _Seg { all, notInvited, waiting, reviewed }

class _PhonebookBodyState extends State<_PhonebookBody> {
  late final List<Customer> list = widget.initial;
  _Seg seg = _Seg.all;
  String q = '';
  bool selecting = false;
  final Set<String> picked = {};
  List<Bundle> groups = [];
  final Map<String, GlobalKey> _letterKeys = {};

  @override
  void initState() {
    super.initState();
    webRepo.bundles().then((b) {
      if (mounted) setState(() => groups = b);
    }).catchError((_) {});
  }

  bool _inSeg(Customer c) => switch (seg) {
        _Seg.all => true,
        _Seg.notInvited => c.status == 'suggested' || c.status == 'approved',
        _Seg.waiting => c.status == 'invited',
        _Seg.reviewed => c.status == 'recorded',
      };

  Future<void> _set(Customer c, String status) async {
    final prev = c.status;
    setState(() => c.status = status);
    try {
      await repo.setCustomerStatus(c.id, status);
    } catch (_) {
      if (mounted) {
        setState(() => c.status = prev);
        showMsg(context, "Couldn't update ${c.name}. Try again.");
      }
    }
  }

  // ---------- add / edit ----------
  void _addContact() {
    final name = TextEditingController(), phone = TextEditingController(), job = TextEditingController();
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setSaving) {
          var saving = false;
          return StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('Add a contact'),
              const SizedBox(height: 14),
              Field('Name', controller: name, hint: 'Jane Smith'),
              Field('Mobile or email', controller: phone, hint: '+44 7700 900123', keyboard: TextInputType.emailAddress),
              Field('Job done', controller: job, hint: 'Roof repair'),
              AppButton(saving ? 'Saving…' : 'Save contact', onTap: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        showMsg(ctx, 'Please enter a name');
                        return;
                      }
                      set(() => saving = true);
                      try {
                        final c = await repo.addCustomer(name: name.text.trim(), job: job.text.trim().isEmpty ? 'Job' : job.text.trim(), contact: phone.text.trim());
                        if (!mounted) return;
                        setState(() => list.insert(0, c));
                        Navigator.pop(ctx);
                        showMsg(context, 'Contact added');
                      } catch (_) {
                        set(() => saving = false);
                        if (ctx.mounted) showMsg(ctx, "Couldn't save the contact. Try again.");
                      }
                    }),
            ]),
          );
        },
      ),
    );
  }

  /// Swipe right. Opens the edit sheet; nothing changes until Save is pressed.
  Future<void> _edit(Customer c) {
    final name = TextEditingController(text: c.name), phone = TextEditingController(text: c.phone), job = TextEditingController(text: c.job);
    return showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) {
          var saving = false;
          return StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('Edit contact'),
              const SizedBox(height: 14),
              Field('Name', controller: name),
              Field('Mobile or email', controller: phone, keyboard: TextInputType.emailAddress),
              Field('Job done', controller: job),
              Row(children: [
                Expanded(child: AppButton('Cancel', style: BtnStyle.ghost, onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(saving ? 'Saving…' : 'Save changes', onTap: saving
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty) {
                            showMsg(ctx, 'Please enter a name');
                            return;
                          }
                          set(() => saving = true);
                          try {
                            await repo.updateCustomer(c.id, name: name.text.trim(), job: job.text.trim(), contact: phone.text.trim());
                            if (!mounted) return;
                            setState(() {
                              c.name = name.text.trim();
                              c.job = job.text.trim();
                              c.phone = phone.text.trim();
                            });
                            Navigator.pop(ctx);
                            showMsg(context, '${c.name} updated');
                          } catch (_) {
                            set(() => saving = false);
                            if (ctx.mounted) showMsg(ctx, "Couldn't save the changes. Try again.");
                          }
                        }),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  /// Swipe left. Always asks first, then removes.
  Future<bool> _confirmRemove(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Remove ${c.name}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('They will be taken out of your phonebook. Videos and invitations already sent are kept.', style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await repo.deleteCustomer(c.id);
      return true;
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't remove ${c.name}. Try again.");
      return false;
    }
  }

  // ---------- groups ----------
  Future<void> _createGroup() async {
    if (picked.isEmpty) {
      showMsg(context, 'Tick the people you want in the group first');
      return;
    }
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Name this group', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Field('Group name', controller: name, hint: 'Roof replacements'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Create', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final b = await webRepo.saveBundle(name: name.text.trim(), memberIds: picked.toList());
      if (!mounted) return;
      setState(() {
        groups.insert(0, b);
        selecting = false;
        picked.clear();
      });
      showSuccess(context, 'Group created');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't create the group. Try again.");
    }
  }

  void _openGroup(Bundle b) {
    final people = list.where((c) => b.memberIds.contains(c.id)).toList();
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        H2(b.name),
        const SizedBox(height: 4),
        Muted('${b.memberIds.length} people · ${b.lastSent}', size: 13),
        const SizedBox(height: 14),
        for (final c in people.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [Avatar(c.name, size: 34), const SizedBox(width: 12), Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)))]),
          ),
        if (people.length > 12) Muted('and ${people.length - 12} more', size: 13),
      ]),
    );
  }

  // ---------- export ----------
  Future<void> _export() async {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = ['Name,Mobile or email,Job done,Status', for (final c in list) [c.name, c.phone, c.job, c.status].map(esc).join(',')];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (mounted) showMsg(context, '${list.length} contacts copied as a spreadsheet (CSV)');
  }

  // ---------- pieces ----------
  Widget _segTile(_Seg s, String label, int n) {
    final on = seg == s;
    return Expanded(
      child: Pressable(
        onTap: () => setState(() => seg = s),
        child: AnimatedContainer(
          duration: kMed,
          curve: kCurve,
          padding: const EdgeInsets.symmetric(vertical: 11),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
            color: on ? null : (C.dark ? C.surface : Colors.white.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? Colors.white.withValues(alpha: 0.4) : (C.dark ? C.border : Colors.white)),
            boxShadow: on ? [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : C.shadow,
          ),
          child: Column(children: [
            Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: on ? Colors.white : C.text)),
            const SizedBox(height: 1),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white70 : C.muted))),
          ]),
        ),
      ),
    );
  }

  Widget _toolButton(String label, IconData icon, VoidCallback onTap, {bool primary = false}) => Expanded(
        child: AppButton(label, icon: icon, small: true, style: primary ? BtnStyle.primary : BtnStyle.ghost, onTap: onTap),
      );

  Widget _swipeBg(Color a, Color b, IconData icon, String label, Alignment al) => Container(
        alignment: al,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(gradient: LinearGradient(colors: al == Alignment.centerLeft ? [a, b] : [b, a])),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );

  Widget _row(Customer c, {required bool last}) {
    final on = picked.contains(c.id);
    final sub = [c.job, if (c.phone.isNotEmpty) c.phone else c.date].where((s) => s.isNotEmpty).join(' · ');
    final row = Pressable(
      scale: 0.99,
      onTap: () {
        if (selecting) {
          setState(() => on ? picked.remove(c.id) : picked.add(c.id));
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactDetailScreen(customer: c))).then((_) {
            if (mounted) setState(() {});
          });
        }
      },
      child: Container(
        color: C.dark ? C.surface : Colors.white.withValues(alpha: 0.0),
        padding: const EdgeInsets.fromLTRB(16, 11, 22, 11),
        child: Row(children: [
          if (selecting) ...[
            AnimatedContainer(
              duration: kFast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
                border: Border.all(color: on ? Colors.transparent : C.border, width: 2),
              ),
              child: on ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
          ],
          Avatar(c.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 1),
              Muted(sub, size: 12.5, maxLines: 1),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(c.status),
        ]),
      ),
    );
    final divided = Container(
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: C.border.withValues(alpha: 0.7), width: 1))),
      child: row,
    );
    if (selecting) return divided;
    return Dismissible(
      key: ValueKey('c_${c.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBg(C.primaryLight, C.primary, Icons.edit_rounded, 'Edit', Alignment.centerLeft),
      secondaryBackground: _swipeBg(const Color(0xFFFF8A80), C.rec, Icons.delete_rounded, 'Remove', Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _edit(c);
          return false;
        }
        return _confirmRemove(c);
      },
      onDismissed: (_) => setState(() {
        list.removeWhere((x) => x.id == c.id);
        picked.remove(c.id);
      }),
      child: divided,
    );
  }

  String _letter(Customer c) {
    final ch = c.name.trim().isEmpty ? '#' : c.name.trim()[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#';
  }

  Widget _directory(List<Customer> shown) {
    final sorted = [...shown]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final byLetter = <String, List<Customer>>{};
    for (final c in sorted) {
      byLetter.putIfAbsent(_letter(c), () => []).add(c);
    }
    final letters = byLetter.keys.toList()..sort((a, b) => a == '#' ? 1 : (b == '#' ? -1 : a.compareTo(b)));
    for (final l in letters) {
      _letterKeys.putIfAbsent(l, () => GlobalKey());
    }
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in letters) ...[
          Padding(
            key: _letterKeys[l],
            padding: const EdgeInsets.fromLTRB(6, 14, 0, 8),
            child: Text(l, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.primary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: C.dark ? null : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.94), Colors.white.withValues(alpha: 0.8)]),
              color: C.dark ? C.surface : null,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: C.dark ? C.border : Colors.white),
              boxShadow: C.shadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(children: [
                for (var i = 0; i < byLetter[l]!.length; i++) _row(byLetter[l]![i], last: i == byLetter[l]!.length - 1),
              ]),
            ),
          ),
        ],
      ]),
      if (letters.length > 3)
        Positioned(
          right: 0,
          top: 40,
          child: GestureDetector(
            onVerticalDragUpdate: (d) {
              final i = ((d.localPosition.dy) / 16).floor().clamp(0, letters.length - 1);
              _jump(letters[i]);
            },
            child: Column(children: [
              for (final l in letters)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jump(l),
                  child: SizedBox(width: 20, height: 16, child: Center(child: Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.primary)))),
                ),
            ]),
          ),
        ),
    ]);
  }

  void _jump(String l) {
    final ctx = _letterKeys[l]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: kMed, curve: kCurve, alignment: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final lower = q.toLowerCase();
    final shown = list.where((c) => _inSeg(c) && (c.name.toLowerCase().contains(lower) || c.phone.toLowerCase().contains(lower) || c.job.toLowerCase().contains(lower))).toList();
    final pending = list.where((c) => c.status == 'suggested').toList();
    int count(_Seg s) => list.where((c) {
          final keep = seg;
          seg = s;
          final r = _inSeg(c);
          seg = keep;
          return r;
        }).length;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: widget.refresh,
        child: AppPage(children: [
          Row(children: [
            _segTile(_Seg.all, 'Everyone', count(_Seg.all)),
            _segTile(_Seg.notInvited, 'Not invited', count(_Seg.notInvited)),
            _segTile(_Seg.waiting, 'Waiting', count(_Seg.waiting)),
            _segTile(_Seg.reviewed, 'Reviewed', count(_Seg.reviewed)),
          ]),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Search a name, phone or job',
              hintStyle: TextStyle(color: C.muted),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: C.muted),
              filled: true,
              fillColor: C.dark ? C.surface : Colors.white.withValues(alpha: 0.9),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.dark ? C.border : Colors.white)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _toolButton('Add', Icons.person_add_alt_rounded, _addContact, primary: true),
            const SizedBox(width: 8),
            _toolButton('Import', Icons.file_upload_outlined, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen()))),
            const SizedBox(width: 8),
            _toolButton('Export', Icons.file_download_outlined, _export),
          ]),
          const SizedBox(height: 14),
          // groups
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.groups_rounded, size: 20, color: C.primary),
                const SizedBox(width: 8),
                Text('Groups', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(width: 6),
                Text('${groups.length}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IntrinsicWidth(
                      child: AppButton(selecting ? 'Cancel' : 'Create group', icon: selecting ? Icons.close_rounded : Icons.add_rounded, small: true, style: selecting ? BtnStyle.ghost : BtnStyle.primary, onTap: () => setState(() {
                            selecting = !selecting;
                            picked.clear();
                          })),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Muted(selecting ? 'Tick people below, then press Create.' : 'Tick people, make a group of them and write to all of them at once.', size: 12.5),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Pressable(
                      onTap: () => _openGroup(groups[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: C.dark ? C.surface2 : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: C.dark ? C.border : Colors.white),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(groups[i].name, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text('${groups[i].memberIds.length} people', style: TextStyle(fontSize: 11.5, color: C.muted)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          if (pending.length > 1 && !selecting) ...[
            const SizedBox(height: 12),
            AppButton('Approve all ${pending.length} suggested', icon: Icons.done_all_rounded, small: true, style: BtnStyle.ghost, onTap: () {
              for (final c in List.of(pending)) {
                _set(c, 'approved');
              }
            }),
          ],
          const SizedBox(height: 14),
          if (!selecting)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.swipe_rounded, size: 15, color: C.muted),
              const SizedBox(width: 6),
              Flexible(child: Text('Swipe right to edit  ·  swipe left to remove', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600))),
            ]),
          if (shown.isEmpty)
            const EmptyState(Icons.contacts_rounded, 'No contacts here', 'Add or import customers to start asking.')
          else
            _directory(shown),
          const SizedBox(height: 90),
        ]),
      ),
      if (selecting)
        Positioned(
          left: 18,
          right: 18,
          bottom: 96,
          child: AppButton(picked.isEmpty ? 'Tick people to group' : 'Create group with ${picked.length}', icon: Icons.groups_rounded, onTap: picked.isEmpty ? null : _createGroup),
        ),
    ]);
  }
}
