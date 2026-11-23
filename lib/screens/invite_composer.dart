import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

/// "Send custom invitation": choose recipient(s), channel and wording.
class InviteComposerScreen extends StatefulWidget {
  final String? to;
  const InviteComposerScreen({super.key, this.to});
  @override
  State<InviteComposerScreen> createState() => _InviteComposerScreenState();
}

class _InviteComposerScreenState extends State<InviteComposerScreen> {
  int channel = 0;
  bool reminder = true;
  late final TextEditingController who = TextEditingController(text: widget.to ?? '');
  final msg = TextEditingController(text: 'Hi {first_name}, thanks for choosing Hartley Roofing. Would you record a quick 2-minute video about how it went? The words are on screen, no app needed. {link}');
  final contacts = demoCustomers().where((c) => c.status != 'skipped').toList();

  @override
  void dispose() {
    who.dispose();
    msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubPage('Custom invitation', children: [
        Field('To', controller: who, hint: 'Name, mobile or email'),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in contacts) AppChip(c.name.split(' ').first, active: who.text == c.name, onTap: () => setState(() => who.text = c.name)),
          ]),
        ),
        const SizedBox(height: 16),
        const H2('Send by'),
        const SizedBox(height: 10),
        Pills(const ['SMS', 'Email', 'WhatsApp'], channel, (i) => setState(() => channel = i)),
        const SizedBox(height: 14),
        Field('Message', controller: msg, lines: 5, onChanged: (_) => setState(() {})),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PREVIEW', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Text(
                msg.text.replaceAll('{first_name}', who.text.isEmpty ? 'there' : who.text.split(' ').first).replaceAll('{link}', 'viewrec.com/r/demo'),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SwitchTile('Send a reminder after 3 days', reminder, (v) => setState(() => reminder = v)),
        const SizedBox(height: 8),
        const Muted('Invitations only go out 8am-8pm, and never to someone who has opted out.', size: 12.5),
        const SizedBox(height: 16),
        AppButton('Send invitation', icon: Icons.send_rounded, onTap: () {
          Navigator.pop(context);
          showMsg(context, 'Invitation sent');
        }),
      ]);
}
