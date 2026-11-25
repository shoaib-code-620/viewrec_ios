import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// Referrals: a link and QR code to share. You earn credit when the business you referred starts paying.
class ReferralHubScreen extends StatelessWidget {
  const ReferralHubScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<ReferralInfo>(
        load: webRepo.referrals,
        builder: (context, r, refresh) => RefreshIndicator(
          color: C.primary,
          onRefresh: refresh,
          child: AppPage(reveal: false, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rLg + 4),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.heroA, C.heroB]),
                border: Border.all(color: C.heroBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your credit', style: TextStyle(color: C.heroSub, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                CountUp(r.creditCents / 100, decimals: 2, prefix: '\$', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text('Credit comes off your next bill, like money.', style: TextStyle(color: C.heroSub, fontSize: 12.5)),
              ]),
            ).reveal(context, 0),
            const SizedBox(height: 14),
            AppCard(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: QrImageView(data: r.link, size: 168, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Muted(r.link, size: 12.5, maxLines: 1, align: TextAlign.center),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: AppButton('Copy link', icon: Icons.copy_rounded, small: true, onTap: () async {
                      await Clipboard.setData(ClipboardData(text: r.link));
                      if (context.mounted) showMsg(context, 'Link copied');
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton('Copy code', small: true, style: BtnStyle.ghost, onTap: () async {
                      await Clipboard.setData(ClipboardData(text: r.code));
                      if (context.mounted) showMsg(context, 'Code copied');
                    }),
                  ),
                ]),
              ]),
            ).reveal(context, 1),
            const SectionHeader('Businesses you referred'),
            if (r.referred.isEmpty) const EmptyState(Icons.card_giftcard_rounded, 'No referrals yet', 'Share your link and earn credit when a business pays.'),
            for (var i = 0; i < r.referred.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Avatar(r.referred[i].name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.referred[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        Muted(r.referred[i].when, size: 12),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(r.referred[i].status == 'paid' ? 'Paid' : 'Signed up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: r.referred[i].status == 'paid' ? C.green : C.amber)),
                      Text(r.referred[i].creditCents > 0 ? '+${_money(r.referred[i].creditCents)}' : 'Waiting', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.muted)),
                    ]),
                  ]),
                ),
              ).reveal(context, 2 + i, 0.08),
            const SizedBox(height: 80),
          ]),
        ),
      );
}
