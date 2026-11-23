import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

/// Admin control: platform-wide view for ViewRec staff.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int tab = 0;
  bool maintenance = false, signups = true;

  static const accounts = [
    ('Hartley Roofing', 'Pro · trial day 4', 'active'),
    ('Bright Smile Dental', 'Standard', 'active'),
    ('Northside Autos', 'Pro Plus', 'active'),
    ('Green Leaf Landscaping', 'Standard · awaiting activation call', 'pending'),
    ('Cobalt Plumbing', 'Pro · payment failed', 'attention'),
  ];

  @override
  Widget build(BuildContext context) => AppPage(children: [
        InfoBanner('Admin control is only visible to ViewRec staff.', icon: Icons.shield_rounded, color: C.amber),
        const SizedBox(height: 14),
        const Row(children: [
          Expanded(child: StatCard(icon: Icons.business_rounded, label: 'Accounts', value: '128')),
          SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.call_rounded, label: 'Activation calls', value: '6', delta: 'waiting')),
        ]),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: StatCard(icon: Icons.videocam_rounded, label: 'Videos today', value: '47')),
          SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.flag_rounded, label: 'Flagged', value: '2', delta: 'needs review')),
        ]),
        const SizedBox(height: 16),
        Pills(const ['Accounts', 'Moderation', 'System'], tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 12),
        if (tab == 0)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < accounts.length; i++)
                Tile(
                  icon: Icons.business_rounded,
                  title: accounts[i].$1,
                  subtitle: accounts[i].$2,
                  divider: i < accounts.length - 1,
                  iconColor: switch (accounts[i].$3) { 'active' => C.green, 'pending' => C.amber, _ => C.rec },
                  onTap: () => showMsg(context, 'Opening ${accounts[i].$1}'),
                ),
            ]),
          ),
        if (tab == 1)
          Column(children: [
            for (final f in const [('Video from Lena Fischer', 'Flagged by customer: wrong business'), ('Written review from Pete W.', 'Contains personal details')])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Muted(f.$2, size: 13),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: AppButton('Keep', small: true, onTap: () => showMsg(context, 'Kept'))),
                      const SizedBox(width: 8),
                      Expanded(child: AppButton('Remove', small: true, style: BtnStyle.danger, onTap: () => showMsg(context, 'Removed'))),
                    ]),
                  ]),
                ),
              ),
          ]),
        if (tab == 2)
          AppCard(
            child: Column(children: [
              SwitchTile('New sign-ups open', signups, (v) => setState(() => signups = v)),
              Divider(color: C.border),
              SwitchTile('Maintenance mode', maintenance, (v) => setState(() => maintenance = v), subtitle: 'Shows a notice to all users'),
            ]),
          ),
        const SizedBox(height: 80),
      ]);
}
