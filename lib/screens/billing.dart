import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../data.dart';
import '../liquid_widgets.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pricing.dart';
import 'referrals.dart';

/// Plan & billing with the website's two tabs.
class BillingTabs extends StatelessWidget {
  const BillingTabs({super.key});
  @override
  Widget build(BuildContext context) => TabbedSection(
        tabs: [
          ('Plan & billing', (_) => const BillingScreen()),
          ('Refer and earn', (_) => const ReferralHubScreen()),
        ],
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  Future<void> _stop(BuildContext context, VoidCallback refresh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Stop your subscription?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Nothing more is charged, and you keep the month you have paid for. You can start again whenever you like.', style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep it', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Stop', style: TextStyle(color: const Color(0xFFE5484D), fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.stopSubscription();
      refresh();
    } catch (_) {
      if (context.mounted) showMsg(context, "Couldn't stop the subscription. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) => AsyncView<BillingInfo>(
        load: repo.billing,
        skeletonCards: 3,
        builder: (context, b, refresh) {
          final plan = plans.firstWhere((p) => p.name == b.plan, orElse: () => plans.first);
          final status = b.stopped ? 'Stopped' : (b.status == 'trial' ? 'Trial' : b.status[0].toUpperCase() + b.status.substring(1));
          final statusColor = b.stopped ? const Color(0xFFE5484D) : C.green;
          return RefreshIndicator(
            onRefresh: refresh,
            child: AppPage(children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Your plan', style: TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w700))),
                    _Badge(status, statusColor),
                  ]),
                  const SizedBox(height: 8),
                  Text(b.plan, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  Text.rich(TextSpan(text: plan.priceLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), children: [
                    if (!plan.custom) TextSpan(text: ' / month', style: TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
                  ])),
                  if (b.status == 'trial' && !b.stopped) ...[
                    const SizedBox(height: 14),
                    Text('Day ${b.trialDay} of ${b.trialLength} of your trial', style: TextStyle(color: C.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LiquidProgress(value: b.trialDay / b.trialLength, minHeight: 6, backgroundColor: C.surface2, color: C.primary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppButton('Change your plan', icon: Icons.swap_horiz_rounded, onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PricingScreen()));
                    refresh();
                  }),
                ]),
              ),
              const SectionHeader('Your subscription'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Row('Plan', b.plan),
                  _Row('Status', status),
                  _Row('Billed to', b.hasCard ? b.cardLabel : 'No card yet'),
                  if (b.stopped && b.endsOn.isNotEmpty) _Row('Runs until', b.endsOn),
                  const SizedBox(height: 6),
                  Muted(b.afterTrialNote, size: 13),
                ]),
              ),
              const SectionHeader('Usage this month'),
              AppCard(
                child: Column(children: [
                  for (final u in b.usage)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(u.label, style: const TextStyle(fontSize: 15)),
                        Text.rich(TextSpan(text: '${u.used}', style: const TextStyle(fontWeight: FontWeight.w800), children: [
                          TextSpan(text: ' / ${u.limit}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w500, fontSize: 13)),
                        ])),
                      ]),
                    ),
                ]),
              ),
              const SectionHeader('Payments'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: b.invoices.isEmpty
                    ? const EmptyState(Icons.receipt_long_rounded, 'No payments yet', 'They will appear here after your first payment.')
                    : Column(children: [
                        for (var i = 0; i < b.invoices.length; i++)
                          Tile(
                            icon: Icons.receipt_long_rounded,
                            title: b.invoices[i].title,
                            subtitle: b.invoices[i].date,
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(b.invoices[i].amount, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              b.invoices[i].status == 'pending' ? _Badge('Pending', C.amber) : _Badge('Paid', C.green),
                            ]),
                            divider: i < b.invoices.length - 1,
                          ),
                      ]),
              ),
              const SectionHeader('Payment method'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(children: [
                  Tile(
                    icon: Icons.credit_card_rounded,
                    title: b.hasCard ? b.cardLabel : 'Add a card',
                    subtitle: b.hasCard ? 'Change or remove your card' : 'Your card is entered on our payment provider\'s page',
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentMethodScreen(current: b.hasCard ? b.cardLabel : '')));
                      refresh();
                    },
                  ),
                  Tile(icon: Icons.mail_outline_rounded, title: 'Billing email', subtitle: b.billingEmail, divider: false, onTap: () {
                    Clipboard.setData(ClipboardData(text: b.billingEmail));
                    showMsg(context, 'Billing email copied');
                  }),
                ]),
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.stopped ? 'Your subscription is stopped' : 'Stop your subscription', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Muted(b.stopped ? 'Nothing more is charged. Start again whenever you like.' : 'Nothing more is charged, and you keep the month you have paid for.', size: 13.5),
                  const SizedBox(height: 14),
                  b.stopped
                      ? AppButton('Start again', icon: Icons.play_arrow_rounded, onTap: () async {
                          try {
                            await repo.resumeSubscription();
                            refresh();
                          } catch (_) {
                            if (context.mounted) showMsg(context, "Couldn't restart the subscription. Try again.");
                          }
                        })
                      : AppButton('Stop your subscription', style: BtnStyle.ghost, onTap: () => _stop(context, refresh)),
                ]),
              ),
              const SizedBox(height: 80),
            ]),
          );
        },
      );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: TextStyle(color: C.muted, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Checks what was typed in the card form. Returns what to fix, or null when it can be sent.
String? cardError({required String number, required String name, required String expiry, required String cvc, DateTime? now}) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (name.trim().length < 2) return 'Enter the name on the card.';
  if (digits.length < 13 || digits.length > 19 || !_luhn(digits)) return 'That card number does not look right.';
  final m = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(expiry.trim());
  if (m == null) return 'Enter the expiry as MM/YY.';
  final month = int.parse(m.group(1)!), year = 2000 + int.parse(m.group(2)!);
  final t = now ?? DateTime.now();
  if (month < 1 || month > 12) return 'The expiry month must be between 01 and 12.';
  if (year < t.year || (year == t.year && month < t.month)) return 'This card has expired.';
  if (!RegExp(r'^\d{3,4}$').hasMatch(cvc.trim())) return 'The security code is 3 or 4 digits.';
  return null;
}

bool _luhn(String d) {
  var sum = 0;
  var alt = false;
  for (var i = d.length - 1; i >= 0; i--) {
    var n = d.codeUnitAt(i) - 48;
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

/// Add, change or remove the card, with a short form. Nothing typed here is kept on the phone: it is sent once, over HTTPS, to be passed to the payment provider.
class PaymentMethodScreen extends StatefulWidget {
  final String current;
  const PaymentMethodScreen({super.key, required this.current});
  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late String card = widget.current;
  bool busy = false;
  late bool adding = widget.current.isEmpty;
  String? error;
  final number = TextEditingController(), name = TextEditingController(), expiry = TextEditingController(), cvc = TextEditingController();

  @override
  void dispose() {
    for (final c in [number, name, expiry, cvc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _format(TextEditingController c, String text) {
    if (text == c.text) return;
    c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  void _onNumber(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    final g = d.length > 19 ? d.substring(0, 19) : d;
    _format(number, [for (var i = 0; i < g.length; i += 4) g.substring(i, i + 4 > g.length ? g.length : i + 4)].join(' '));
  }

  void _onExpiry(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    final g = d.length > 4 ? d.substring(0, 4) : d;
    _format(expiry, g.length > 2 ? '${g.substring(0, 2)}/${g.substring(2)}' : g);
  }

  Future<void> _save() async {
    final e = cardError(number: number.text, name: name.text, expiry: expiry.text, cvc: cvc.text);
    if (e != null) {
      setState(() => error = e);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.saveCard(number: number.text, name: name.text, expiry: expiry.text, cvc: cvc.text);
      final b = await repo.billing();
      for (final c in [number, name, expiry, cvc]) {
        c.clear();
      }
      if (mounted) {
        setState(() {
          card = b.cardLabel;
          adding = false;
        });
        showMsg(context, 'Card saved');
      }
    } catch (_) {
      if (mounted) setState(() => error = "Couldn't save the card. Check the details and try again.");
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _remove() async {
    setState(() => busy = true);
    try {
      await repo.removeCard();
      if (mounted) {
        setState(() {
          card = '';
          adding = true;
        });
      }
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't remove the card. Try again.");
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppPage(children: [
          const BackHeader('Payment method'),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const GlossIcon(Icons.credit_card_rounded, Color(0xFF0FA386), size: 46),
                const SizedBox(width: 14),
                Expanded(child: Text(card.isEmpty ? 'No card yet' : card, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 12),
              Muted(card.isEmpty ? 'Add a card to keep your plan going after the trial.' : 'This card is charged for your plan each month.', size: 13.5),
              if (!adding) ...[
                const SizedBox(height: 16),
                AppButton('Change your card', icon: Icons.edit_rounded, onTap: busy ? null : () => setState(() => adding = true)),
                const SizedBox(height: 10),
                AppButton('Remove this card', style: BtnStyle.ghost, onTap: busy ? null : _remove),
              ],
            ]),
          ),
          if (adding) ...[
            const SectionHeader('Card details'),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Field('Name on card', hint: 'As shown on the card', controller: name),
                Field('Card number', hint: '1234 5678 9012 3456', controller: number, keyboard: TextInputType.number, onChanged: _onNumber),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Field('Expiry', hint: 'MM/YY', controller: expiry, keyboard: TextInputType.number, onChanged: _onExpiry)),
                  const SizedBox(width: 12),
                  Expanded(child: Field('Security code', hint: 'CVC', controller: cvc, keyboard: TextInputType.number)),
                ]),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                AppButton(busy ? 'Saving…' : 'Save card', icon: Icons.lock_rounded, onTap: busy ? null : _save),
                if (card.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppButton('Cancel', style: BtnStyle.ghost, onTap: busy ? null : () => setState(() => adding = false)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 14),
          const Muted('Your card details are sent securely to our payment provider. The app does not keep them, and we store only the last four digits.', size: 12.5, align: TextAlign.center),
        ]),
      );
}
