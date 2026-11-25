import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import '../theme.dart';
import '../widgets.dart';
import 'verification.dart';

class AdditionalServicesScreen extends StatelessWidget {
  const AdditionalServicesScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color, Widget)>[
      (Icons.card_giftcard_rounded, 'Customer rewards', 'Loyalty rewards and discount coupons for customers who review you', C.amber, const RewardsScreen()),
      (Icons.campaign_rounded, 'Ads management', 'We run your Google, Meta and Local Services ads', C.blue, const ManagedServicesScreen()),
      (Icons.support_agent_rounded, 'Your own agent', 'An agent available around the clock', C.green, const ManagedServicesScreen()),
      (Icons.verified_user_rounded, 'Verification', 'Get your blue tick so you can post your own photos and videos', C.blue, const _VerificationPage()),
      (Icons.verified_rounded, 'Business profiles', 'We keep your Google and social profiles active', C.primary, const ManagedServicesScreen()),
      (Icons.people_alt_rounded, 'Referral credit', 'Earn credit for businesses you bring', C.rec, const ReferralsScreen()),
      (Icons.call_rounded, 'Talk to our team', 'Book a setup call', C.primary, const TalkToTeamScreen()),
    ];
    return AppPage(children: [
      const Muted('Extras that grow with you. Add what you need, when you need it.'),
      const SizedBox(height: 14),
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () => _go(context, i.$5),
            child: Row(children: [
              GlossIcon(i.$1, i.$4, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Muted(i.$3, size: 12.5),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        ),
      const SizedBox(height: 80),
    ]);
  }
}

/// The verification screen on its own page, for when it is opened from this list.
class _VerificationPage extends StatelessWidget {
  const _VerificationPage();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader('Verification')),
              const Expanded(child: VerificationScreen()),
            ]),
          ),
        ]),
      );
}

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int tab = 0;
  final coupons = [
    ('10% off next service', 'REVIEW10', 14, true),
    ('£20 off a re-roof', 'ROOF20', 3, true),
    ('Free gutter clean', 'GUTTER', 0, false),
  ];

  @override
  Widget build(BuildContext context) => SubPage('Customer rewards', children: [
        const Muted('Say thank you to customers who record a video. Pro Plus includes up to 15 loyalty rewards a month.'),
        const SizedBox(height: 14),
        Pills(const ['Coupons', 'Loyalty'], tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 14),
        if (tab == 0) ...[
          for (final c in coupons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: C.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.local_offer_rounded, color: C.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Muted('Code ${c.$2} · ${c.$3} redeemed', size: 12.5),
                    ]),
                  ),
                  LiquidSwitch(value: c.$4, onChanged: (_) {}),
                ]),
              ),
            ),
          AppButton('Create coupon', icon: Icons.add_rounded, onTap: () => showSheet(
                context,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const H2('New coupon'),
                  const SizedBox(height: 14),
                  const Field('Offer', hint: '10% off your next service'),
                  const Field('Code', hint: 'THANKS10'),
                  const Field('Expires (days after reviewing)', hint: '30', keyboard: TextInputType.number),
                  AppButton('Save coupon', onTap: () {
                    Navigator.pop(context);
                    showMsg(context, 'Coupon created');
                  }),
                ]),
              )),
        ] else ...[
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rewards sent this month', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              Text('2 / 15', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.primary)),
              SizedBox(height: 10),
              LiquidProgress(value: 2 / 15, minHeight: 8, backgroundColor: C.surface2, color: C.primary),
            ]),
          ),
          const SizedBox(height: 14),
          const InfoBanner('Customers get a reward by text right after their video is approved.', icon: Icons.card_giftcard_rounded),
        ],
      ]);
}

class ManagedServicesScreen extends StatelessWidget {
  const ManagedServicesScreen({super.key});
  @override
  Widget build(BuildContext context) => SubPage('Managed Services', children: [
        const H1('We run your marketing', size: 24),
        const SizedBox(height: 8),
        const Muted('Priced to the work. Ad budgets are paid separately.'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(children: [
            for (final f in const [
              'Everything in Pro Plus',
              'Your own agent, available around the clock',
              'We run your Google, Meta and Local Services ads',
              'Your business profiles kept active',
              'Customer rewards handled by our team',
              'Scope and fee tailored to your business',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: C.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        AppButton('Talk to our team', icon: Icons.call_rounded, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TalkToTeamScreen()))),
      ]);
}

class ReferralsScreen extends StatelessWidget {
  const ReferralsScreen({super.key});
  @override
  Widget build(BuildContext context) => SubPage('Referral credit', children: [
        const InfoBanner('Earn credit for every business you bring to ViewRec.', icon: Icons.people_alt_rounded),
        const SizedBox(height: 14),
        const Row(children: [
          Expanded(child: StatCard(icon: Icons.people_outline_rounded, label: 'Referred', value: '3')),
          SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.savings_rounded, label: 'Credit earned', value: '\$98')),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
          child: Row(children: [
            const Expanded(child: Text('https://viewrec.com/join/demo', style: TextStyle(fontFamily: 'monospace', fontSize: 12.5))),
            IconButton(icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () => showMsg(context, 'Copied')),
          ]),
        ),
        const SizedBox(height: 12),
        AppButton('Share your link', icon: Icons.ios_share_rounded, onTap: () => showMsg(context, 'Share sheet opens here')),
      ]);
}

class TalkToTeamScreen extends StatefulWidget {
  const TalkToTeamScreen({super.key});
  @override
  State<TalkToTeamScreen> createState() => _TalkToTeamScreenState();
}

class _TalkToTeamScreenState extends State<TalkToTeamScreen> {
  bool sent = false;
  @override
  Widget build(BuildContext context) => SubPage('Talk to our team', children: [
        if (sent) ...[
          const SizedBox(height: 40),
          Center(child: CircleAvatar(radius: 36, backgroundColor: C.green, child: Icon(Icons.check_rounded, size: 36, color: Colors.white))),
          const SizedBox(height: 20),
          const Center(child: H2('Thanks - we will call you')),
          const SizedBox(height: 8),
          const Muted('Someone from our team will be in touch within one working day.', align: TextAlign.center),
          const SizedBox(height: 24),
          AppButton('Done', onTap: () => Navigator.pop(context)),
        ] else ...[
          const Muted('Tell us about your business and the jobs you do. We will tell you honestly what your customer list can become.'),
          const SizedBox(height: 16),
          const Field('Your name', initial: 'demo'),
          const Field('Business', initial: 'Hartley Roofing'),
          const Field('Phone', hint: '+44 …', keyboard: TextInputType.phone),
          const Field('What would you like help with?', lines: 4, hint: 'e.g. getting past customers to record videos'),
          AppButton('Request a call', icon: Icons.call_rounded, onTap: () => setState(() => sent = true)),
        ],
      ]);
}
