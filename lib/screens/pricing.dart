import 'package:flutter/material.dart';
import '../data.dart';
import '../motion.dart';
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
              padding: const EdgeInsets.only(bottom: 18),
              child: PlanTicket(plan: p, yearly: yearly),
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

class PlanTicket extends StatelessWidget {
  final dynamic plan;
  final bool yearly;
  const PlanTicket({super.key, required this.plan, required this.yearly});
  @override
  Widget build(BuildContext context) {
    final p = plan;
    final blue = p.recommended as bool;
    final fg = blue ? Colors.white : C.text;
    final sub = blue ? Colors.white70 : C.muted;
    final price = yearly ? (p.price * 10 / 12).round() : p.price;
    return TicketCard(
      blue: blue,
      top: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg))),
          if (blue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradYellow),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: const Color(0xFFF2A100).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Text('Recommended', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0B1B3A))),
            ),
        ]),
        const SizedBox(height: 4),
        Text(p.blurb as String, style: TextStyle(fontSize: 14, color: sub, height: 1.4)),
        const SizedBox(height: 18),
        Text.rich(TextSpan(
          text: '\$$price',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -2, color: fg),
          children: [TextSpan(text: '  / month', style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w600, letterSpacing: 0))],
        )),
      ]),
      bottom: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final f in p.features as List)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.check_rounded, size: 18, color: blue ? const Color(0xFFFFC21A) : C.green)),
              const SizedBox(width: 10),
              Expanded(child: Text(f as String, style: TextStyle(fontSize: 14, color: fg, height: 1.35))),
            ]),
          ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => showMsg(context, 'Checkout is not connected yet'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: blue ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD65A), Color(0xFFF2A100)]) : null,
              color: blue ? null : (C.dark ? C.surface2 : const Color(0xFFE6EFFF)),
              borderRadius: BorderRadius.circular(999),
              boxShadow: blue ? [BoxShadow(color: const Color(0xFFF2A100).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))] : null,
            ),
            child: Text('Start for \$1', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: blue ? const Color(0xFF0B1B3A) : C.primary)),
          ),
        ),
      ]),
    );
  }
}
