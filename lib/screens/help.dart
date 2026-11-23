import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'additional_services.dart';
import 'assistant.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const faqs = [
    ('What does the \$1 actually do?', 'It starts your 15 days. In that time you can invite as many customers as you like and use everything. It is a dollar so that starting means something - free trials get signed up for and forgotten.'),
    ('What happens after 15 days?', 'You pick the plan that fits. If you stop, the days you have paid for still run.'),
    ('Does my customer need an app or an account?', 'No. They open one link, record in their browser in about two minutes, and the words are on screen.'),
    ('What if somebody says something I do not want to use?', 'You approve every video before anyone sees it. Nothing is published without your yes.'),
    ('Can I post straight to Facebook and Instagram?', 'Yes, on Pro and above. You choose each post - nothing goes out on its own.'),
    ('What about people who do not want to be asked?', 'An opt-out is final. Someone who says stop is never contacted again, by you or anyone else we work with.'),
    ('When are invitations sent?', 'Between 8am and 8pm where your business is, and never to the same person twice in six months.'),
  ];

  @override
  Widget build(BuildContext context) => SubPage('Help & FAQs', children: [
        Row(children: [
          Expanded(
            child: AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
              child: const Column(children: [
                Icon(Icons.auto_awesome_rounded, color: C.primary),
                SizedBox(height: 8),
                Text('Ask the assistant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TalkToTeamScreen())),
              child: Column(children: [
                Icon(Icons.call_rounded, color: C.green),
                SizedBox(height: 8),
                Text('Talk to our team', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
            ),
          ),
        ]),
        const SectionHeader('Frequently asked'),
        for (final f in faqs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: C.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd), side: BorderSide(color: C.border)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: C.primary,
                  collapsedIconColor: C.muted,
                  title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  children: [Muted(f.$2, size: 14)],
                ),
              ),
            ),
          ),
      ]);
}
