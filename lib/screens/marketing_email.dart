import 'package:flutter/material.dart';
import '../motion.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Marketing email: one email to your customers. Opted-out people and anyone contacted too recently are skipped.
class MarketingEmailScreen extends StatefulWidget {
  const MarketingEmailScreen({super.key});
  @override
  State<MarketingEmailScreen> createState() => _MarketingEmailScreenState();
}

class _MarketingEmailScreenState extends State<MarketingEmailScreen> {
  final subject = TextEditingController();
  final body = TextEditingController();
  int audience = 0; // All contacts, Approved only
  bool sending = false;

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (subject.text.trim().isEmpty || body.text.trim().length < 20) {
      showMsg(context, 'Add a subject and a message of at least 20 characters.');
      return;
    }
    setState(() => sending = true);
    try {
      final r = await webRepo.sendMarketingEmail(subject: subject.text.trim(), body: body.text.trim(), audience: audience == 0 ? 'all' : 'approved');
      if (!mounted) return;
      showSuccess(context, 'Sent to ${r.sent} people');
      setState(() {
        subject.clear();
        body.clear();
      });
      if (r.excluded > 0) showMsg(context, '${r.excluded} skipped: opted out or contacted too recently');
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        const Muted('Write to your customers about an offer or news. Every email has an unsubscribe link, and sending waits for 8am to 8pm in each person\'s time zone.').reveal(context, 0),
        const SizedBox(height: 14),
        Pills(const ['All contacts', 'Approved only'], audience, (i) => setState(() => audience = i)).reveal(context, 1),
        const SizedBox(height: 14),
        Field('Subject', controller: subject, hint: 'A thank you from Hartley Roofing').reveal(context, 2),
        Field('Message', controller: body, lines: 8, hint: 'Hi,\n\nThank you for choosing us...').reveal(context, 3),
        const InfoBanner('People who opted out, and anyone emailed in the last 180 days, are skipped automatically.', icon: Icons.shield_outlined).reveal(context, 4),
        const SizedBox(height: 14),
        AppButton('Send email', icon: Icons.send_rounded, loading: sending, onTap: _send).reveal(context, 5),
        const SizedBox(height: 80),
      ]);
}
