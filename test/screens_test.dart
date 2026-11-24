import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewrec/data.dart';
import 'package:viewrec/media_data.dart';
import 'package:viewrec/models.dart';
import 'package:viewrec/screens/inbox.dart';
import 'package:viewrec/screens/media_viewers.dart';
import 'package:viewrec/screens/additional_services.dart';
import 'package:viewrec/screens/assistant.dart';
import 'package:viewrec/screens/contact_detail.dart';
import 'package:viewrec/screens/help.dart';
import 'package:viewrec/screens/import.dart';
import 'package:viewrec/screens/insights.dart';
import 'package:viewrec/screens/invite_composer.dart';
import 'package:viewrec/screens/lead_thread.dart';
import 'package:viewrec/screens/notifications.dart';
import 'package:viewrec/screens/pricing.dart';
import 'package:viewrec/screens/record.dart';
import 'package:viewrec/screens/settings.dart';
import 'package:viewrec/screens/video_detail.dart';
import 'package:viewrec/screens/welcome.dart';
import 'package:viewrec/shell.dart';
import 'package:viewrec/theme.dart';

/// Draws every screen in light and dark, on a small phone, at normal and large
/// text size. Any overflow or layout error fails that screen's test.
final screens = <String, Widget Function()>{
  'Welcome': () => const WelcomeScreen(),
  'Sign in': () => const SignInScreen(),
  'Start trial 1': () => const StartTrialScreen(),
  'Start trial 2': () => const StartTrialScreen(initialStep: 1),
  'Start trial 3': () => const StartTrialScreen(initialStep: 2),
  'Overview': () => const Shell(initialIndex: 0),
  'Testimonials': () => const Shell(initialIndex: 1),
  'Create content': () => const Shell(initialIndex: 2),
  'Phonebook': () => const Shell(initialIndex: 3),
  'Leads': () => const Shell(initialIndex: 4),
  'Automations': () => const Shell(initialIndex: 5),
  'Your pages': () => const Shell(initialIndex: 6),
  'Publishing': () => const Shell(initialIndex: 7),
  'Connected accounts': () => const Shell(initialIndex: 8),
  'Billing': () => const Shell(initialIndex: 9),
  'Settings': () => const Shell(initialIndex: 10),
  'Admin': () => const Shell(initialIndex: 11),
  'Additional services': () => const Shell(initialIndex: 12),
  'Notifications': () => const NotificationsScreen(),
  'Assistant': () => const AssistantScreen(),
  'Help': () => const HelpScreen(),
  'Insights': () => const InsightsScreen(),
  'Pricing': () => const PricingScreen(),
  'Invite composer': () => const InviteComposerScreen(to: 'Sarah Mitchell'),
  'Import 1': () => const ImportScreen(),
  'Import 2 mapping': () => const ImportScreen(initialStep: 1),
  'Import 3 results': () => const ImportScreen(initialStep: 2),
  'Import 4 approve': () => const ImportScreen(initialStep: 3),
  'Video detail pending': () => VideoDetailScreen(video: demoVideos().first),
  'Video detail published': () => VideoDetailScreen(video: demoVideos()[1]),
  'Contact detail': () => ContactDetailScreen(customer: demoCustomers()[3]),
  'Contact suggested': () => ContactDetailScreen(customer: demoCustomers()[0]),
  'Lead thread': () => LeadThreadScreen(
        lead: Lead(id: 'l1', name: 'Rebecca Shaw', service: 'Roof inspection', message: 'Hi, I saw your video reviews. Can someone look at a leak above our bay window this week?', when: '12 min ago', source: 'Directory', status: 'new'),
      ),
  'Business profile': () => const BusinessProfileScreen(),
  'Branding': () => const BrandingScreen(),
  'Opt-outs': () => const OptOutsScreen(),
  'Team': () => const TeamScreen(),
  'Notification prefs': () => const NotificationPrefsScreen(),
  'Rewards': () => const RewardsScreen(),
  'Managed services': () => const ManagedServicesScreen(),
  'Referrals': () => const ReferralsScreen(),
  'Talk to team': () => const TalkToTeamScreen(),
  'Record consent': () => const RecordScreen(),
  'Record rate': () => const RecordScreen(initialStage: Stage.rate),
  'Record choose': () => const RecordScreen(initialStage: Stage.choose),
  'Record write': () => const RecordScreen(initialStage: Stage.write),
  'Record avatar': () => const RecordScreen(initialStage: Stage.avatar),
  'Record done': () => const RecordScreen(initialStage: Stage.done),
  'Media feed': () => const Shell(initialIndex: kMediaIndex),
  'More': () => const Shell(initialIndex: kMoreIndex),
  'Inbox': () => const InboxScreen(),
  'Story viewer': () => StoryViewer(groups: demoStories().where((g) => !g.mine).toList()),
  'Reels viewer': () => ReelsViewer(reels: demoReels(), onChanged: () {}),
};

void main() {
  for (final dark in [true, false]) {
    for (final scale in [1.0, 1.3]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} | ${dark ? 'dark' : 'light'} | text x$scale', (tester) async {
          tester.view.physicalSize = const Size(720, 1480); // 360 x 740 logical at 2x
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          C.dark = dark;
          final captured = <FlutterErrorDetails>[];
          final previous = FlutterError.onError;
          FlutterError.onError = captured.add;
          await tester.pumpWidget(MaterialApp(
            theme: buildTheme(dark: dark),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: e.value(),
          ));
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 700));
          FlutterError.onError = previous;
          if (captured.isNotEmpty) {
            final found = <String>{};
            void texts(RenderObject r, List<String> out) {
              if (out.length >= 3) return;
              if (r is RenderParagraph) out.add(r.text.toPlainText().replaceAll('\n', ' '));
              r.visitChildren((c) => texts(c, out));
            }

            void walk(RenderObject r) {
              if (r is RenderFlex && r.hasSize) {
                final horizontal = r.direction == Axis.horizontal;
                var sum = 0.0;
                var n = 0;
                r.visitChildren((c) {
                  if (c is RenderBox && c.hasSize) {
                    sum += horizontal ? c.size.width : c.size.height;
                    n++;
                  }
                });
                final avail = horizontal ? r.size.width : r.size.height;
                if (sum > avail + 0.5) {
                  final t = <String>[];
                  texts(r, t);
                  found.add('${horizontal ? "ROW" : "COL"} w=${avail.round()} needs=${sum.round()} [${t.join(' / ')}]');
                }
              }
              r.visitChildren(walk);
            }

            walk(tester.renderObject(find.byType(MaterialApp)));
            fail('LAYOUT: ${found.take(4).join(' ;; ')}');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
