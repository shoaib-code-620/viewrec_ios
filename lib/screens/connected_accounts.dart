import 'package:flutter/material.dart';
import '../async_view.dart';
import '../data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

class ConnectedAccountsScreen extends StatelessWidget {
  const ConnectedAccountsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<Map<String, String>>(
        load: repo.accounts,
        skeletonCards: 3,
        builder: (context, accounts, refresh) => _AccountsBody(initial: accounts, refresh: refresh),
      );
}

class _AccountsBody extends StatefulWidget {
  final Map<String, String> initial;
  final Future<void> Function() refresh;
  const _AccountsBody({required this.initial, required this.refresh});
  @override
  State<_AccountsBody> createState() => _AccountsBodyState();
}

class _AccountsBodyState extends State<_AccountsBody> {
  late final Map<String, String> connected = Map.of(widget.initial);
  final busy = <String>{};

  Future<void> _run(Platform p, Future<void> Function() action, VoidCallback onOk, String okMsg) async {
    setState(() => busy.add(p.id));
    try {
      await action();
      if (mounted) {
        setState(onOk);
        showMsg(context, okMsg);
      }
    } catch (_) {
      if (mounted) showMsg(context, "That didn't work. Please try again.");
    } finally {
      if (mounted) setState(() => busy.remove(p.id));
    }
  }

  void _toggle(Platform p) {
    final name = p.name.split(' ').first;
    if (connected.containsKey(p.id)) {
      showSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2('Disconnect $name?'),
          const SizedBox(height: 8),
          const Muted('Scheduled posts to this account will be paused. You can reconnect any time.'),
          const SizedBox(height: 16),
          AppButton('Disconnect', style: BtnStyle.danger, onTap: () {
            Navigator.pop(context);
            _run(p, () => repo.disconnectAccount(p.id), () => connected.remove(p.id), '$name disconnected');
          }),
          const SizedBox(height: 8),
          AppButton('Keep connected', style: BtnStyle.ghost, onTap: () => Navigator.pop(context)),
        ]),
      );
    } else {
      showSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2('Connect $name'),
          const SizedBox(height: 8),
          const Muted('You will be sent to sign in and allow ViewRec to post on your behalf. We only post what you approve.'),
          const SizedBox(height: 16),
          AppButton('Continue', icon: Icons.open_in_new_rounded, onTap: () {
            Navigator.pop(context);
            _run(p, () => repo.connectAccount(p.id), () => connected[p.id] = 'Hartley Roofing', '$name connected');
          }),
        ]),
      );
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: widget.refresh,
        child: AppPage(children: [
          const Muted('Link the places you want your testimonials to appear.'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: StatCard(icon: Icons.link_rounded, label: 'Accounts linked', value: '${connected.length}')),
            const SizedBox(width: 12),
            Expanded(child: StatCard(icon: Icons.add_link_rounded, label: 'Available', value: '${platforms.length - connected.length}')),
          ]),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < platforms.length; i++)
                Tile(
                  icon: platforms[i].icon,
                  title: platforms[i].name,
                  subtitle: connected[platforms[i].id] ?? 'Not connected',
                  divider: i < platforms.length - 1,
                  iconColor: connected.containsKey(platforms[i].id) ? C.green : C.muted,
                  trailing: busy.contains(platforms[i].id)
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _toggle(platforms[i]),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: connected.containsKey(platforms[i].id) ? C.border : C.primary),
                              foregroundColor: connected.containsKey(platforms[i].id) ? C.muted : C.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: Text(connected.containsKey(platforms[i].id) ? 'Manage' : 'Connect', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          const InfoBanner('Threads is also supported on Pro Plus - 11 platforms in total.'),
          const SizedBox(height: 80),
        ]),
      );
}
