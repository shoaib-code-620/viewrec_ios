import 'package:flutter/material.dart';
import '../data.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

/// Change your plan: every plan with what it includes and what is switched on, and a button to move to it.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  BillingInfo? billing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await repo.billing();
      if (mounted) setState(() => billing = b);
    } catch (_) {}
  }

  Future<void> _switch(Plan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Switch to ${p.name}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${p.name} is ${p.priceLabel} a month. It is charged on the same card, and you can move to another plan or stop at any time.', style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Not now', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Switch', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.changePlan(p.id);
      if (!mounted) return;
      showMsg(context, 'You are on ${p.name}');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't change your plan. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppPage(children: [
          const BackHeader('Change your plan'),
          const Muted('Move up or down whenever you like. Pick what fits and we switch it on.'),
          const SizedBox(height: 16),
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: p.custom
                  ? _ManagedCard(plan: p)
                  : PlanTicket(plan: p, current: billing?.plan == p.name, onSelect: billing == null ? null : () => _switch(p)),
            ),
          const SizedBox(height: 40),
        ]),
      );
}

/// Managed Services: priced for each business, so it is a conversation and not a button.
class _ManagedCard extends StatelessWidget {
  final Plan plan;
  const _ManagedCard({required this.plan});
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted(plan.blurb, size: 13.5),
          const SizedBox(height: 14),
          const Text('Custom', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 14),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.check_rounded, size: 18, color: C.green)),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 14, height: 1.35))),
              ]),
            ),
          const SizedBox(height: 8),
          AppButton('Talk to our team', icon: Icons.call_rounded, style: BtnStyle.ghost, onTap: () => showMsg(context, 'We will get in touch')),
        ]),
      );
}

/// One plan as a ticket: its price, what it includes, an expandable "On this plan" list, and the button to move to it.
class PlanTicket extends StatelessWidget {
  final Plan plan;
  final bool yearly;
  /// This is the plan the business is on now.
  final bool current;
  /// Moves to this plan. Without it the button says "Start for $1", as on the welcome page.
  final VoidCallback? onSelect;
  const PlanTicket({super.key, required this.plan, this.yearly = false, this.current = false, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final blue = p.recommended;
    final fg = blue ? Colors.white : C.text;
    final sub = blue ? Colors.white70 : C.muted;
    final price = yearly ? (p.price * 10 / 12).round() : p.price;
    final label = current ? 'Your plan' : (onSelect != null ? 'Switch to ${p.name}' : 'Start for \$1');
    return TicketCard(
      blue: blue,
      top: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg))),
          if (current)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: blue ? Colors.white.withValues(alpha: 0.2) : C.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
              child: Text('Your plan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: blue ? Colors.white : C.green)),
            )
          else if (blue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradYellow),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: const Color(0xFFF2A100).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Text('Recommended', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0B1B3A))),
            ),
        ]),
        const SizedBox(height: 4),
        Text(p.blurb, style: TextStyle(fontSize: 13.5, color: sub, height: 1.4)),
        const SizedBox(height: 18),
        Text.rich(TextSpan(
          text: '\$$price',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -2, color: fg),
          children: [TextSpan(text: '  / month', style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w600, letterSpacing: 0))],
        )),
      ]),
      bottom: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final f in p.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.check_rounded, size: 18, color: blue ? const Color(0xFFFFC21A) : C.green)),
              const SizedBox(width: 10),
              Expanded(child: Text(f, style: TextStyle(fontSize: 14, color: fg, height: 1.35))),
            ]),
          ),
        if (p.onThisPlan.isNotEmpty) _OnThisPlan(items: p.onThisPlan, fg: fg, sub: sub, blue: blue),
        const SizedBox(height: 8),
        Pressable(
          onTap: current ? () {} : (onSelect ?? () => showMsg(context, 'Checkout is not connected yet')),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: blue && !current ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD65A), Color(0xFFF2A100)]) : null,
              color: blue && !current ? null : (current ? (blue ? Colors.white.withValues(alpha: 0.18) : C.surface2) : (C.dark ? C.surface2 : const Color(0xFFE6EFFF))),
              borderRadius: BorderRadius.circular(999),
              boxShadow: blue && !current ? [BoxShadow(color: const Color(0xFFF2A100).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (current) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_rounded, size: 18, color: blue ? Colors.white : C.muted)),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: current ? (blue ? Colors.white : C.muted) : (blue ? const Color(0xFF0B1B3A) : C.primary))),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// "On this plan (12)": a tap opens everything that is switched on for the plan. Things still being built are marked.
class _OnThisPlan extends StatefulWidget {
  final List<(String, bool)> items;
  final Color fg, sub;
  final bool blue;
  const _OnThisPlan({required this.items, required this.fg, required this.sub, required this.blue});
  @override
  State<_OnThisPlan> createState() => _OnThisPlanState();
}

class _OnThisPlanState extends State<_OnThisPlan> {
  bool open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Pressable(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text('On this plan (${widget.items.length})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: widget.fg))),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: kFast, child: Icon(Icons.keyboard_arrow_down_rounded, color: widget.sub)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: kMed,
          curve: kCurve,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final i in widget.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.only(top: 6, right: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.sub))),
                          Expanded(
                            child: Text.rich(TextSpan(text: i.$1, style: TextStyle(fontSize: 13, color: widget.fg, height: 1.35), children: [
                              if (i.$2) TextSpan(text: '  in build', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.blue ? const Color(0xFFFFC21A) : C.amber)),
                            ])),
                          ),
                        ]),
                      ),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]);
}
