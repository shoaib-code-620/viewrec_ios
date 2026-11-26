import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'bundles.dart';
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
  final _scroll = ScrollController();
  final _topKey = GlobalKey();
  double _topH = 560;
  String? bubble; // the big letter shown while dragging along the index
  static const _alphabet = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'];

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
    final d = await askGroupDetails(context);
    if (d == null) return;
    try {
      final b = await webRepo.saveBundle(name: d.name, memberIds: picked.toList(), purpose: d.purpose, note: d.note);
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

  double get _scale => MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
  double get _rowH => 68.0 * _scale;
  static const _headerH = 32.0;

  Widget _row(Customer c, {required bool last}) {
    final on = picked.contains(c.id);
    final sub = [c.job, if (c.phone.isNotEmpty) c.phone else c.date].where((s) => s.isNotEmpty).join(' · ');
    final content = Pressable(
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
      // Room on the right keeps the A-Z index clear of the status and the swipe area.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 34, 0),
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
          Avatar(c.name, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 1),
              Muted(sub, size: 13, maxLines: 1),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(c.status),
        ]),
      ),
    );
    final row = SizedBox(
      height: _rowH,
      child: Column(children: [
        Expanded(child: content),
        // A thin line that starts under the name, like a phone's contact list.
        Container(height: 1, margin: EdgeInsets.only(left: selecting ? 98 : 76), color: last ? Colors.transparent : C.border.withValues(alpha: 0.8)),
      ]),
    );
    if (selecting) return row;
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
      child: row,
    );
  }

  String _letter(Customer c) {
    final ch = c.name.trim().isEmpty ? '#' : c.name.trim()[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#';
  }

  /// People sorted by name and grouped under their first letter ('#' for anything else, last).
  (List<String>, Map<String, List<Customer>>) _grouped(List<Customer> shown) {
    final sorted = [...shown]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final by = <String, List<Customer>>{};
    for (final c in sorted) {
      by.putIfAbsent(_letter(c), () => []).add(c);
    }
    final letters = by.keys.toList()..sort((a, b) => a == '#' ? 1 : (b == '#' ? -1 : a.compareTo(b)));
    return (letters, by);
  }

  /// Scrolls so the section for [letter] sits at the top. A letter with nobody under it goes to the next one that has people.
  void _jumpTo(String letter, List<String> letters, Map<String, List<Customer>> by, {bool animate = false}) {
    final i = _alphabet.indexOf(letter);
    final target = letters.firstWhere((l) => _alphabet.indexOf(l) >= i, orElse: () => letters.last);
    var offset = _topH;
    for (final l in letters) {
      if (l == target) break;
      offset += _headerH + by[l]!.length * _rowH;
    }
    if (!_scroll.hasClients) return;
    final to = offset.clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(to, duration: kMed, curve: kCurve);
    } else {
      _scroll.jumpTo(to);
    }
  }

  /// The A-Z strip down the right edge, fixed to the screen and centred. Tap a letter or slide along it.
  Widget _indexBar(List<String> letters, Map<String, List<Customer>> by) => LayoutBuilder(
        builder: (context, box) {
          final itemH = (box.maxHeight / _alphabet.length).clamp(11.0, 17.0);
          String at(double dy) => _alphabet[(dy / itemH).floor().clamp(0, _alphabet.length - 1)];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final l = at(d.localPosition.dy);
              setState(() => bubble = l);
              _jumpTo(l, letters, by, animate: true);
            },
            onTapUp: (_) => setState(() => bubble = null),
            onTapCancel: () => setState(() => bubble = null),
            onVerticalDragUpdate: (d) {
              final l = at(d.localPosition.dy);
              if (l != bubble) setState(() => bubble = l);
              _jumpTo(l, letters, by);
            },
            onVerticalDragEnd: (_) => setState(() => bubble = null),
            child: SizedBox(
              width: 26,
              height: itemH * _alphabet.length,
              child: Column(children: [
                for (final l in _alphabet)
                  SizedBox(
                    height: itemH,
                    child: Center(
                      child: Text(l, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: letters.contains(l) ? C.primary : C.muted.withValues(alpha: 0.45))),
                    ),
                  ),
              ]),
            ),
          );
        },
      );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    final (letters, by) = _grouped(shown);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _topKey.currentContext?.size?.height;
      if (h != null && h != _topH) _topH = h;
    });
    final headerColor = C.dark ? C.surface2 : const Color(0xFFEAF1FC);
    return Stack(children: [
      if (!BackdropScope.active(context)) const Positioned.fill(child: LiquidBackdrop()),
      SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: widget.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  key: _topKey,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                          Text(groups[i].name, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('${groups[i].memberIds.length} people · ${groups[i].purposeLabel}', style: TextStyle(fontSize: 12, color: C.muted)),
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
                    const SizedBox(height: 10),
                  ]),
                ),
              ),
              if (shown.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: EmptyState(Icons.contacts_rounded, 'No contacts here', 'Add or import customers to start asking.')))
              else
                for (final l in letters)
                  SliverMainAxisGroup(slivers: [
                    SliverPersistentHeader(pinned: true, delegate: _LetterHeader(l, _headerH, headerColor)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _row(by[l]![i], last: i == by[l]!.length - 1),
                        childCount: by[l]!.length,
                      ),
                    ),
                  ]),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
      if (shown.length >= 6)
        Positioned(
          right: 2,
          top: 120,
          bottom: 130,
          // Hidden while the controls at the top fill the screen, so it never sits on top of them.
          child: AnimatedBuilder(
            animation: _scroll,
            builder: (context, _) {
              final vh = MediaQuery.sizeOf(context).height;
              final off = _scroll.hasClients ? _scroll.offset : 0.0;
              final show = off >= _topH - vh * 0.5;
              return IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(duration: kFast, opacity: show ? 1 : 0, child: Align(alignment: Alignment.centerRight, child: _indexBar(letters, by))),
              );
            },
          ),
        ),
      if (bubble != null)
        Positioned(
          right: 44,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue),
                boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Text(bubble!, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            ),
          ),
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

/// A letter that stays at the top of the screen while its people scroll underneath, like a phone's contacts.
class _LetterHeader extends SliverPersistentHeaderDelegate {
  final String letter;
  final double height;
  final Color color;
  _LetterHeader(this.letter, this.height, this.color);
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        height: height,
        color: color,
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        child: Text(letter, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.primary)),
      );
  @override
  bool shouldRebuild(covariant _LetterHeader old) => old.letter != letter || old.color != color || old.height != height;
}
