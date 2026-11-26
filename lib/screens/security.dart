import 'package:flutter/material.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Security: two-step sign-in by email code, and the devices that are signed in to your account.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<SecurityInfo>(
        load: webRepo.security,
        builder: (context, s, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(info: s)),
      );
}

class _Body extends StatefulWidget {
  final SecurityInfo info;
  const _Body({required this.info});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final s = widget.info;

  Future<void> _toggle(bool on) async {
    setState(() => s.twoFactor = on);
    try {
      await webRepo.setTwoFactor(on);
      if (mounted) showMsg(context, on ? 'Two-step sign-in is on' : 'Two-step sign-in is off');
    } catch (_) {
      if (mounted) {
        setState(() => s.twoFactor = !on);
        showMsg(context, "Couldn't change that. Try again.");
      }
    }
  }

  Future<void> _revoke(SignedInDevice d) async {
    setState(() => s.devices.remove(d));
    try {
      await webRepo.revokeDevice(d.id);
    } catch (_) {
      if (mounted) setState(() => s.devices.add(d));
    }
  }

  Future<void> _signOutOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: const Text('Sign out other devices?'),
        content: const Text('Everywhere except this phone will be signed out and need your password again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign out', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final others = s.devices.where((d) => !d.current).toList();
    setState(() => s.devices.removeWhere((d) => !d.current));
    try {
      await webRepo.signOutOtherDevices();
      if (mounted) showMsg(context, 'Signed out of ${others.length} other ${others.length == 1 ? 'device' : 'devices'}');
    } catch (_) {
      if (mounted) setState(() => s.devices.addAll(others));
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = s.devices.where((d) => !d.current).length;
    return AppPage(reveal: false, children: [
      AppCard(
        child: SwitchTile('Two-step sign-in', s.twoFactor, _toggle, subtitle: 'After your password, we email a 6-digit code. Anyone who learns your password still cannot get in.'),
      ).reveal(context, 0),
      const SectionHeader('Where you are signed in'),
      for (var i = 0; i < s.devices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: s.devices[i].current ? C.green.withValues(alpha: 0.15) : C.surface2),
                child: Icon(s.devices[i].device.toLowerCase().contains('phone') || s.devices[i].device.toLowerCase().contains('iphone') ? Icons.smartphone_rounded : Icons.laptop_rounded, color: s.devices[i].current ? C.green : C.muted, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.devices[i].device, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Muted('${s.devices[i].place} · ${s.devices[i].when}', size: 12.5),
                ]),
              ),
              if (s.devices[i].current)
                Text('This device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.green))
              else
                TextButton(onPressed: () => _revoke(s.devices[i]), child: Text('Sign out', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
            ]),
          ),
        ).reveal(context, 1 + i, 0.08),
      if (others > 0) ...[
        const SizedBox(height: 6),
        AppButton('Sign out all other devices', icon: Icons.logout_rounded, small: true, style: BtnStyle.danger, onTap: _signOutOthers),
      ],
      const SizedBox(height: 80),
    ]);
  }
}
