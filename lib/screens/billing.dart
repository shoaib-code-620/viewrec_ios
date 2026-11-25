import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pricing.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) => AsyncView<BillingInfo>(
        load: repo.billing,
        skeletonCards: 3,
        builder: (context, b, refresh) => RefreshIndicator(
          onRefresh: refresh,
          child: AppPage(children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.heroA, C.heroB], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(rLg),
                border: Border.all(color: C.heroBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('CURRENT PLAN', style: TextStyle(color: C.accentText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: C.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                    child: Text(b.status == 'trial' ? 'Trial' : b.status[0].toUpperCase() + b.status.substring(1),
                        style: TextStyle(color: C.green, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(b.plan, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (b.status == 'trial')
                  Text('Day ${b.trialDay} of ${b.trialLength} · ${b.afterTrialNote}', style: TextStyle(color: C.heroSub, height: 1.4)),
                if (b.status == 'trial') ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LiquidProgress(value: b.trialDay / b.trialLength, minHeight: 6, backgroundColor: C.heroPillBorder, color: C.primary),
                  ),
                ],
                const SizedBox(height: 14),
                AppButton('Change plan', icon: Icons.swap_horiz_rounded, small: true, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PricingScreen()))),
              ]),
            ),
            const SectionHeader('Usage this month'),
            AppCard(
              child: Column(children: [
                for (final u in b.usage)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(u.label, style: const TextStyle(fontSize: 14.5)),
                      Text.rich(TextSpan(text: '${u.used}', style: const TextStyle(fontWeight: FontWeight.w800), children: [
                        TextSpan(text: ' / ${u.limit}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w500, fontSize: 12.5)),
                      ])),
                    ]),
                  ),
              ]),
            ),
            const SectionHeader('Payment'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                Tile(
                  icon: Icons.credit_card_rounded,
                  title: b.hasCard ? 'Card on file' : 'No card on file',
                  subtitle: b.hasCard ? 'Manage your payment method' : 'An activation agent calls before anything starts',
                  onTap: () => showMsg(context, 'Add a card when your trial ends'),
                ),
                Tile(icon: Icons.receipt_long_rounded, title: 'Billing email', subtitle: b.billingEmail, divider: false, onTap: () {
                  Clipboard.setData(ClipboardData(text: b.billingEmail));
                  showMsg(context, 'Billing email copied');
                }),
              ]),
            ),
            const SectionHeader('Invoices'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: b.invoices.isEmpty
                  ? const EmptyState(Icons.receipt_long_rounded, 'No invoices yet', 'They will appear here after your first payment.')
                  : Column(children: [
                      for (var i = 0; i < b.invoices.length; i++)
                        Tile(
                          icon: Icons.description_rounded,
                          title: b.invoices[i].title,
                          subtitle: b.invoices[i].date,
                          trailing: Text(b.invoices[i].amount, style: const TextStyle(fontWeight: FontWeight.w700)),
                          divider: i < b.invoices.length - 1,
                          onTap: () => showMsg(context, 'Invoice downloaded'),
                        ),
                    ]),
            ),
            const SizedBox(height: 16),
            const Muted('If you stop, the days you have paid for still run.', size: 12.5, align: TextAlign.center),
            const SizedBox(height: 80),
          ]),
        ),
      );
}
