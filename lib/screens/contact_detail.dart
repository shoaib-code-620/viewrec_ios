import 'package:flutter/material.dart';
import '../calls.dart';
import '../data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'invite_composer.dart';

/// One customer: details, what has happened so far, and the next action.
class ContactDetailScreen extends StatefulWidget {
  final Customer customer;
  const ContactDetailScreen({super.key, required this.customer});
  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Customer get c => widget.customer;
  bool busy = false;

  static const _order = ['suggested', 'approved', 'invited', 'recorded'];

  Future<void> _set(String status) async {
    final prev = c.status;
    setState(() {
      c.status = status;
      busy = true;
    });
    try {
      await repo.setCustomerStatus(c.id, status);
    } catch (_) {
      if (mounted) {
        setState(() => c.status = prev);
        showMsg(context, "Couldn't update ${c.name}. Try again.");
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _optOut() => showSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2('Stop contacting ${c.name.split(' ').first}?'),
          const SizedBox(height: 8),
          const Muted('They will be added to your opt-out list. An opt-out is final: they will never be contacted again, by you or anyone else we work with.'),
          const SizedBox(height: 16),
          AppButton('Add to opt-out list', style: BtnStyle.danger, onTap: () {
            Navigator.pop(context);
            _set('skipped');
          }),
          const SizedBox(height: 8),
          AppButton('Cancel', style: BtnStyle.ghost, onTap: () => Navigator.pop(context)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final reached = c.status == 'skipped' ? 0 : _order.indexOf(c.status);
    final events = <(String, String, bool)>[
      ('Added to your phonebook', c.date, true),
      ('Approved for an invitation', 'You approved this customer', reached >= 1),
      ('Invitation sent', 'By text and email, between 8am and 8pm', reached >= 2),
      ('Reminder scheduled', 'One reminder after 3 days if there is no reply', reached >= 2),
      ('Testimonial received', 'Waiting for your approval', reached >= 3),
    ];
    final first = c.name.split(' ').first.toLowerCase();
    return SubPage(c.name, children: [
      Center(child: Avatar(c.name, size: 72)),
      const SizedBox(height: 12),
      Center(child: Text(c.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      const SizedBox(height: 4),
      Center(child: Muted('${c.job} · ${c.date}', size: 13)),
      const SizedBox(height: 10),
      Center(child: StatusBadge(c.status)),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: AppButton('Call', icon: Icons.call_rounded, small: true, style: BtnStyle.ghost, onTap: () => callPhone(context, name: c.name, phone: c.phone))),
        const SizedBox(width: 8),
        Expanded(child: AppButton('Message', icon: Icons.sms_rounded, small: true, style: BtnStyle.ghost, onTap: () => showMsg(context, 'Opening messages…'))),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton('Invite', icon: Icons.send_rounded, small: true, onTap: c.status == 'skipped'
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteComposerScreen(to: c.name)))),
        ),
      ]),
      if (c.status == 'suggested') ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: AppButton(busy ? 'Saving…' : 'Approve', small: true, onTap: busy ? null : () => _set('approved'))),
          const SizedBox(width: 8),
          Expanded(child: AppButton('Skip', small: true, style: BtnStyle.ghost, onTap: busy ? null : () => _set('skipped'))),
        ]),
      ],
      const SectionHeader('Details'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          const Tile(icon: Icons.phone_rounded, title: 'Mobile', subtitle: '+44 7700 900123'),
          Tile(icon: Icons.mail_outline_rounded, title: 'Email', subtitle: '$first@example.com'),
          Tile(icon: Icons.build_rounded, title: 'Job done', subtitle: c.job),
          Tile(icon: Icons.lightbulb_outline_rounded, title: 'Why we suggested them', subtitle: c.reason, divider: false),
        ]),
      ),
      const SectionHeader('Timeline'),
      AppCard(
        child: c.status == 'skipped'
            ? Row(children: [
                Icon(Icons.block_rounded, color: C.muted),
                const SizedBox(width: 12),
                const Expanded(child: Muted('This customer will not be contacted.')),
              ])
            : Column(children: [
                for (var i = 0; i < events.length; i++)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: events[i].$3 ? C.green : C.surface2, shape: BoxShape.circle, border: Border.all(color: events[i].$3 ? C.green : C.border)),
                        child: events[i].$3 ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
                      if (i < events.length - 1) Container(width: 2, height: 34, color: events[i].$3 && events[i + 1].$3 ? C.green : C.border),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(events[i].$1, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: events[i].$3 ? C.text : C.muted)),
                          const SizedBox(height: 2),
                          Muted(events[i].$2, size: 12.5),
                        ]),
                      ),
                    ),
                  ]),
              ]),
      ),
      if (c.status != 'skipped') ...[
        const SizedBox(height: 16),
        Center(child: TextButton.icon(onPressed: _optOut, icon: Icon(Icons.block_rounded, size: 16, color: C.rec), label: Text('Never contact this person', style: TextStyle(color: C.rec)))),
      ],
    ]);
  }
}
