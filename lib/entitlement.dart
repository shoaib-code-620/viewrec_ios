import 'package:flutter/material.dart';
import 'models.dart';
import 'repo.dart';
import 'theme.dart';
import 'widgets.dart';

/// What the account's plan allows. Mirrors the website's rules: a trial runs as Pro for its length,
/// and paid plans unlock features in tiers. The server enforces the same rules; this only explains them in the app.
class Entitlement {
  final String plan, status;
  final int trialDay, trialLength;
  const Entitlement({required this.plan, required this.status, required this.trialDay, required this.trialLength});

  factory Entitlement.from(BillingInfo b) => Entitlement(plan: b.plan, status: b.status, trialDay: b.trialDay, trialLength: b.trialLength);

  static int _tier(String plan) => switch (plan.toLowerCase().replaceAll(' ', '')) {
        'standard' => 1,
        'pro' => 2,
        'proplus' => 3,
        'managed' => 4,
        _ => 0,
      };

  /// A trial runs with Pro features.
  int get tier => status == 'trial' ? 2 : _tier(plan);

  /// Whether the account may collect, approve, invite or change settings at all.
  bool get active => status == 'trial' || status == 'active';

  int get trialDaysLeft => (trialLength - trialDay).clamp(0, 999);

  static const _needs = <String, int>{
    'contact_bundles': 2,
    'embeds': 2,
    'subtitles': 2,
    'social_posting': 2,
    'avatar_mode': 2,
    'auto_reminders': 2,
    'remove_watermark': 3,
  };

  static const _planFor = {2: 'Pro', 3: 'Pro Plus'};

  bool allows(String feature) => active && tier >= (_needs[feature] ?? 0);

  String planNeeded(String feature) => _planFor[_needs[feature] ?? 2] ?? 'Pro';
}

Future<Entitlement> loadEntitlement() async => Entitlement.from(await repo.billing());

/// Explains why a feature is locked and what to do about it.
void showUpgrade(BuildContext context, Entitlement e, String feature, String label) {
  final need = e.planNeeded(feature);
  showSheet(
    context,
    Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: C.primarySoft, shape: BoxShape.circle),
        child: Icon(e.active ? Icons.lock_rounded : Icons.pause_circle_rounded, color: C.primary, size: 30),
      ),
      const SizedBox(height: 14),
      Text(e.active ? '$label is on $need and above' : 'Your plan is not active', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Muted(e.active ? 'You are on ${e.status == 'trial' ? 'a trial' : e.plan}. Change your plan under Plan & billing to use this.' : 'Start or renew a plan under Plan & billing to keep using this.', size: 13.5, align: TextAlign.center),
      const SizedBox(height: 18),
      AppButton('Got it', small: true, onTap: () => Navigator.pop(context)),
      const SizedBox(height: 4),
    ]),
  );
}

/// A strip on Home: trial days left, or a plan that needs attention.
class EntitlementBanner extends StatelessWidget {
  final VoidCallback onBilling;
  const EntitlementBanner({super.key, required this.onBilling});

  @override
  Widget build(BuildContext context) => FutureBuilder<Entitlement>(
        future: loadEntitlement(),
        builder: (context, snap) {
          final e = snap.data;
          if (e == null) return const SizedBox.shrink();
          final trial = e.status == 'trial';
          if (e.status == 'active') return const SizedBox.shrink();
          final warn = !trial || e.trialDaysLeft <= 3;
          final color = warn ? C.rec : C.primary;
          final text = trial
              ? (e.trialDaysLeft <= 0 ? 'Your trial has ended. Choose a plan to keep going.' : 'Trial: ${e.trialDaysLeft} ${e.trialDaysLeft == 1 ? 'day' : 'days'} left. You have Pro features until it ends.')
              : e.status == 'past_due'
                  ? 'A payment failed. Update your card to keep your account active.'
                  : 'Your plan is not active. Choose a plan to collect, approve and invite.';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: onBilling,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(rMd), border: Border.all(color: color.withValues(alpha: 0.35))),
                child: Row(children: [
                  Icon(trial ? Icons.hourglass_bottom_rounded : Icons.warning_amber_rounded, size: 20, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.text, height: 1.35))),
                  Icon(Icons.chevron_right_rounded, size: 20, color: color),
                ]),
              ),
            ),
          );
        },
      );
}
