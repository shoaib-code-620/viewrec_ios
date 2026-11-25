import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Workspaces: the businesses you belong to. Switch between your own and ones you help run.
class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<Workspace>>(
        load: webRepo.workspaces,
        skeletonCards: 2,
        builder: (context, list, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(initial: list)),
      );
}

class _Body extends StatefulWidget {
  final List<Workspace> initial;
  const _Body({required this.initial});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final list = List.of(widget.initial);

  Future<void> _switch(Workspace w) async {
    if (w.current) return;
    HapticFeedback.mediumImpact();
    final before = [for (final x in list) x.current];
    setState(() {
      for (final x in list) {
        x.current = x.id == w.id;
      }
    });
    try {
      await webRepo.switchWorkspace(w.id);
      if (mounted) showMsg(context, 'Now working in ${w.name}');
    } catch (_) {
      if (mounted) {
        setState(() {
          for (var i = 0; i < list.length; i++) {
            list[i].current = before[i];
          }
        });
        showMsg(context, "Couldn't switch. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        Muted(list.length > 1 ? 'You belong to ${list.length} businesses. What you can do in each depends on your role.' : 'You work in one business.').reveal(context, 0),
        const SizedBox(height: 14),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => _switch(list[i]),
              borderColor: list[i].current ? C.primary : null,
              borderWidth: list[i].current ? 2 : 1,
              child: Row(children: [
                Avatar(list[i].name, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Muted(list[i].role, size: 12.5),
                  ]),
                ),
                AnimatedSwitcher(
                  duration: kMed,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: list[i].current
                      ? Container(key: const ValueKey('on'), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)), child: Text('Current', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.green)))
                      : Icon(Icons.swap_horiz_rounded, key: const ValueKey('off'), color: C.muted),
                ),
              ]),
            ),
          ).reveal(context, 1 + i, 0.08),
        const SizedBox(height: 80),
      ]);
}
