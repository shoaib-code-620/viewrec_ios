import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool yearly = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppPage(children: [
          const BackHeader('Plans'),
          const H1('Choose the level of support you need', size: 26),
          const SizedBox(height: 8),
          const Muted(
              'Start for \$1. Someone from our team calls and switches your account on, then you have 15 days of full Pro.'),
          const SizedBox(height: 16),
          Wrap(runSpacing: 8, children: [
            AppChip('Monthly', active: !yearly, onTap: () => setState(() => yearly = false)),
            AppChip('Yearly · 2 months free', active: yearly, onTap: () => setState(() => yearly = true)),
          ]),
          const SizedBox(height: 16),
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                borderColor: p.recommended ? C.primary : null,
                borderWidth: p.recommended ? 2 : 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (p.recommended)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Recommended', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Muted(p.blurb, size: 14),
                  const SizedBox(height: 12),
                  Text.rich(TextSpan(
                    text: '\$${yearly ? (p.price * 10 / 12).round() : p.price}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(text: ' / month', style: TextStyle(fontSize: 14, color: C.muted, fontWeight: FontWeight.w500)),
                    ],
                  )),
                  const SizedBox(height: 12),
                  for (final f in p.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.check_circle_rounded, size: 17, color: C.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  AppButton('Start for \$1',
                      style: p.recommended ? BtnStyle.primary : BtnStyle.ghost,
                      onTap: () => showMsg(context, 'Checkout is not connected yet')),
                ]),
              ),
            ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Managed Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Muted('We run your Google, Meta and Local Services ads, with your own agent around the clock.',
                  size: 14),
              const SizedBox(height: 16),
              AppButton('Talk to our team',
                  icon: Icons.call_rounded,
                  style: BtnStyle.ghost,
                  onTap: () => showMsg(context, 'We will get in touch')),
            ]),
          ),
        ]),
      );
}
