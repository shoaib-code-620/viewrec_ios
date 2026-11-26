import 'package:flutter/material.dart';
import '../widgets.dart';
import 'bundles.dart';
import 'calendar.dart';
import 'embeds.dart';
import 'invitations.dart';
import 'marketing_email.dart';
import 'phonebook.dart';
import 'automations.dart';
import 'publishing.dart';
import 'scheduled.dart';
import 'publishing_where.dart';
import 'settings_extra.dart';

/// Business Phonebook with the website's sub tabs: customers, groups and the calendar.
class PhonebookTabs extends StatelessWidget {
  final int initial;
  const PhonebookTabs({super.key, this.initial = 0});
  @override
  Widget build(BuildContext context) => TabbedSection(
        initial: initial,
        storageKey: 'phonebook_tabs',
        tabs: [
          ('Your customers', (_) => const PhonebookScreen()),
          ('Invitations sent', (_) => const InvitationsScreen()),
          ('Groups', (_) => const _GroupsTab()),
          ('Calendar', (_) => const CalendarScreen()),
        ],
      );
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: AppButton('Write an email to a group', icon: Icons.campaign_rounded, small: true, style: BtnStyle.ghost, onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubPageShell(title: 'Email a group', child: MarketingEmailScreen())));
          }),
        ),
        const Expanded(child: BundlesScreen()),
      ]);
}

/// Automations with the website's two tabs: what is scheduled, and the defaults.
class AutomationsTabs extends StatelessWidget {
  final int initial;
  const AutomationsTabs({super.key, this.initial = 0});
  @override
  Widget build(BuildContext context) => TabbedSection(
        initial: initial,
        storageKey: 'automations_tabs',
        tabs: [
          ('Scheduled', (_) => const ScheduledScreen()),
          ('Defaults', (_) => const AutomationsScreen()),
        ],
      );
}

/// Publishing with the website's sub tabs: the queue, and your own website (embeds).
class PublishingTabs extends StatelessWidget {
  final int initial;
  const PublishingTabs({super.key, this.initial = 0});
  @override
  Widget build(BuildContext context) => TabbedSection(
        initial: initial,
        storageKey: 'publishing_tabs',
        tabs: [
          ('Where they go', (_) => const PublishingWhereScreen()),
          ('Queue & history', (_) => const PublishingScreen()),
          ('On your website', (_) => const EmbedsScreen()),
        ],
      );
}
