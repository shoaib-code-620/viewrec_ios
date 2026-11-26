import 'package:flutter/material.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Admin control: invite a team member and choose exactly what they can open. Billing, Settings and this screen stay with the owner.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<TeamMember>>(
        load: webRepo.teamMembers,
        skeletonCards: 3,
        builder: (context, team, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _TeamBody(initial: team)),
      );
}

class _TeamBody extends StatefulWidget {
  final List<TeamMember> initial;
  const _TeamBody({required this.initial});
  @override
  State<_TeamBody> createState() => _TeamBodyState();
}

class _TeamBodyState extends State<_TeamBody> {
  late final List<TeamMember> team = List.of(widget.initial);
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  final access = <String, String>{for (final s in teamSections) s.$1: 'none'};
  String method = 'invite';
  bool sending = false;
  String? error;
  static const seats = 10;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (team.length >= seats) return setState(() => error = 'Your team is full ($seats of $seats).');
    if (name.text.trim().isEmpty) return setState(() => error = 'Add their name');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) return setState(() => error = 'Enter a valid email address');
    if (access.values.every((v) => v == 'none')) return setState(() => error = 'Tick at least one thing they can open');
    if (method == 'password' && password.text.length < 8) return setState(() => error = 'A password needs at least 8 characters');
    setState(() {
      error = null;
      sending = true;
    });
    try {
      final m = await webRepo.inviteTeamMember(name: name.text.trim(), email: email.text.trim(), access: Map.of(access), method: method, password: method == 'password' ? password.text : null);
      if (!mounted) return;
      setState(() {
        team.add(m);
        name.clear();
        email.clear();
        password.clear();
        for (final k in access.keys) {
          access[k] = 'none';
        }
      });
      showSuccess(context, 'Invitation sent to ${m.email}');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _remove(TeamMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Remove ${m.name}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('They lose access straight away.', style: TextStyle(color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await webRepo.removeTeamMember(m.id);
      if (mounted) setState(() => team.removeWhere((x) => x.id == m.id));
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't remove them. Try again.");
    }
  }

  /// One section's three choices: No access, View or Edit.
  Widget _picker(Map<String, String> map, String key, void Function(void Function()) set) => Row(children: [
        for (final o in const [('none', 'No access'), ('view', 'View'), ('edit', 'Edit')])
          Expanded(
            child: Pressable(
              onTap: () => set(() => map[key] = o.$1),
              child: AnimatedContainer(
                duration: kFast,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: map[key] == o.$1 && o.$1 != 'none' ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
                  color: map[key] == o.$1 ? (o.$1 == 'none' ? C.surface2 : null) : C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: map[key] == o.$1 ? (o.$1 == 'none' ? C.muted : Colors.transparent) : C.border),
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(o.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: map[key] == o.$1 && o.$1 != 'none' ? Colors.white : C.text))),
              ),
            ),
          ),
      ]);

  Widget _accessList(Map<String, String> map, void Function(void Function()) set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Overview', style: TextStyle(fontWeight: FontWeight.w700))),
          Text('Always included', style: TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
        for (final s in teamSections)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              Muted(s.$3, size: 12.5),
              const SizedBox(height: 8),
              _picker(map, s.$1, set),
            ]),
          ),
      ]);

  void _edit(TeamMember m) {
    final copy = Map<String, String>.of(m.access);
    var saving = false;
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2(m.name),
          Muted(m.email, size: 13),
          const SizedBox(height: 14),
          const Text('What they can open', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _accessList(copy, set),
          const SizedBox(height: 16),
          AppButton(saving ? 'Saving…' : 'Save access', loading: saving, onTap: saving
              ? null
              : () async {
                  if (copy.values.every((v) => v == 'none')) {
                    showMsg(ctx, 'Leave at least one thing they can open, or remove them.');
                    return;
                  }
                  set(() => saving = true);
                  try {
                    await webRepo.updateTeamAccess(m.id, copy);
                    if (!mounted) return;
                    setState(() => m.access = copy);
                    if (ctx.mounted) Navigator.pop(ctx);
                    showMsg(context, 'Access updated for ${m.name}');
                  } catch (_) {
                    set(() => saving = false);
                    if (ctx.mounted) showMsg(ctx, "Couldn't save. Try again.");
                  }
                }),
        ]),
      ),
    );
  }

  String _summary(TeamMember m) {
    final edit = [for (final s in teamSections) if (m.access[s.$1] == 'edit') s.$2];
    final view = [for (final s in teamSections) if (m.access[s.$1] == 'view') s.$2];
    return [if (edit.isNotEmpty) 'Edit: ${edit.join(', ')}', if (view.isNotEmpty) 'View: ${view.join(', ')}'].join('\n');
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Invite a team member'),
            const SizedBox(height: 4),
            const Muted('They get their own sign-in and see only what you tick here. Billing, Settings and this screen stay yours.', size: 13),
            const SizedBox(height: 14),
            Field('Name', controller: name, hint: 'Sara (front desk)'),
            Field('Email', controller: email, hint: 'sara@example.com', keyboard: TextInputType.emailAddress),
            const Text('What they can open', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            StatefulBuilder(builder: (context, set) => _accessList(access, (f) {
                  setState(f);
                  set(() {});
                })),
            const SizedBox(height: 12),
            const Muted('View opens the screens; nothing on them can be changed. Edit lets them use the forms and buttons too. Plan & billing, Settings and Admin control are never shared.', size: 12.5),
          ]),
        ),
        const SectionHeader('How they get in'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in const [('invite', 'Email them an invitation', 'They choose their own password from a link. Safest.'), ('password', 'Set a password for them', 'You choose it. It is emailed to them with the invitation.')])
              Pressable(
                onTap: () => setState(() => method = o.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: Icon(method == o.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: method == o.$1 ? C.primary : C.muted, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Muted(o.$3, size: 12.5),
                      ]),
                    ),
                  ]),
                ),
              ),
            if (method == 'password') ...[
              const SizedBox(height: 8),
              Field('Password', controller: password, hint: 'At least 8 characters'),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
            const SizedBox(height: 8),
            AppButton(sending ? 'Sending…' : 'Send invitation', icon: Icons.send_rounded, loading: sending, onTap: sending ? null : _invite),
          ]),
        ),
        SectionHeader('Your team  ${team.length} of $seats'),
        if (team.isEmpty)
          const EmptyState(Icons.group_outlined, 'Nobody else has access yet', 'Invite someone above.')
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < team.length; i++)
                Tile(
                  icon: Icons.person_outline_rounded,
                  leading: Avatar(team[i].name, size: 42),
                  title: team[i].name,
                  subtitle: '${team[i].email}${team[i].pending ? '  ·  Invitation sent' : ''}\n${_summary(team[i])}',
                  divider: i < team.length - 1,
                  onTap: () => _edit(team[i]),
                  trailing: IconButton(tooltip: 'Remove', onPressed: () => _remove(team[i]), icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20)),
                ),
            ]),
          ),
        const SizedBox(height: 120),
      ]);
}
