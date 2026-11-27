import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'motion.dart';
import 'screens/support_chat.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

/// Remembers what a first-time user has been shown: the welcome tour, the tips on key screens and the finished checklist.
class GuideStore {
  static const _kTour = 'guide_tour_seen';
  static const _kTips = 'guide_tips_on';
  static const _kSeen = 'guide_tips_seen';
  static const _kDone = 'guide_setup_done_seen';

  /// Set when someone signs in or starts the trial, so the Shell shows the tour once it is on screen.
  static bool pendingTour = false;
  static bool tourSeen = false, tipsOn = false, setupDoneSeen = false;
  static final Set<String> seenTips = {};
  /// Bumped whenever something changes, so tips and cards can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static bool _loaded = false;

  /// For tests: forget everything, as on a fresh install.
  @visibleForTesting
  static void resetForTest() {
    pendingTour = false;
    tourSeen = false;
    tipsOn = false;
    setupDoneSeen = false;
    seenTips.clear();
    _loaded = false;
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      tourSeen = p.getBool(_kTour) ?? false;
      tipsOn = p.getBool(_kTips) ?? false;
      setupDoneSeen = p.getBool(_kDone) ?? false;
      seenTips
        ..clear()
        ..addAll(p.getStringList(_kSeen) ?? const []);
    } catch (_) {}
    _loaded = true;
    revision.value++;
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kTour, tourSeen);
      await p.setBool(_kTips, tipsOn);
      await p.setBool(_kDone, setupDoneSeen);
      await p.setStringList(_kSeen, seenTips.toList());
    } catch (_) {}
  }

  /// The tour was finished or skipped: from now on the key screens show their tip once.
  static Future<void> tourFinished() async {
    tourSeen = true;
    tipsOn = true;
    pendingTour = false;
    revision.value++;
    await _save();
  }

  static Future<void> dismissTip(String id) async {
    seenTips.add(id);
    revision.value++;
    await _save();
  }

  static Future<void> setTips(bool on) async {
    tipsOn = on;
    if (on) seenTips.clear();
    revision.value++;
    await _save();
  }

  static Future<void> setupDoneShown() async {
    setupDoneSeen = true;
    revision.value++;
    await _save();
  }

  /// Opens the tour on top of the current screen.
  static Future<void> showTour(BuildContext context) =>
      Navigator.of(context).push(PageRouteBuilder(opaque: true, transitionDuration: kMed, pageBuilder: (_, __, ___) => const GuideTourScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)));
}

const _tourPages = <(IconData, String, String, Color)>[
  (Icons.people_alt_rounded, 'Add your customers', 'Import or add the people you have worked with. They are the ones who will review you.', Color(0xFF3E94F5)),
  (Icons.send_rounded, 'Send them a link', 'Text, email, WhatsApp or a QR code. Nothing to install, and they do not need to log in.', Color(0xFF0FA386)),
  (Icons.videocam_rounded, 'They record, you approve', 'Your customer records a short video, or writes a review. Nothing goes public until you approve it.', Color(0xFFFF6B5E)),
  (Icons.rocket_launch_rounded, 'Share it everywhere', 'Put approved videos on your website, your social accounts and the Media tab, and win more customers.', Color(0xFFF2A100)),
];

/// A short, skippable tour for people who open the app for the first time.
class GuideTourScreen extends StatefulWidget {
  const GuideTourScreen({super.key});
  @override
  State<GuideTourScreen> createState() => _GuideTourScreenState();
}

class _GuideTourScreenState extends State<GuideTourScreen> {
  final controller = PageController();
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await GuideStore.tourFinished();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == _tourPages.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('tour_skip'),
                onPressed: _finish,
                child: Text('Skip', style: TextStyle(color: C.muted, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => page = i),
                children: [for (final p in _tourPages) _TourPage(icon: p.$1, title: p.$2, body: p.$3, color: p.$4)],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _tourPages.length; i++)
                AnimatedContainer(
                  duration: kMed,
                  curve: kCurve,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == page ? C.primary : C.border, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: AppButton(
                last ? 'Start' : 'Next',
                icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onTap: () {
                  if (last) {
                    _finish();
                  } else {
                    controller.nextPage(duration: kMed, curve: kCurve);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TourPage extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  const _TourPage({required this.icon, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    Widget disc = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, 0.3)!]), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 14))]),
      child: Icon(icon, size: 56, color: Colors.white),
    );
    Widget ring = Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.4), width: 2)));
    if (!still) {
      ring = ring.animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(1.7, 1.7), duration: 2400.ms, curve: Curves.easeOut).fadeOut(duration: 2400.ms);
      disc = disc.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 2200.ms, curve: Curves.easeInOut);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 200, child: Stack(alignment: Alignment.center, children: [ring, disc])),
        const SizedBox(height: 28),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.45, color: C.muted)),
      ]),
    );
  }
}

/// The tip for a key screen: one short line and a "Got it", shown once and only after the tour.
class GuideTip extends StatelessWidget {
  final int section;
  const GuideTip({super.key, required this.section});

  static const _tips = <int, (String, String)>{
    0: ('Your dashboard', 'The blue card shows your results. Get started below walks you through setup, step by step.'),
    1: ('Your reviews', 'Videos from customers land here. Open one, check it, and approve it before anyone sees it.'),
    2: ('Create', 'Turn a review into a post: pick a maker, add captions and your logo, then publish.'),
    3: ('Your customers', 'Add or import the people you have worked with, then send each one a link to record a video.'),
    7: ('Publishing', 'Approved videos wait here. Connect an account, then choose where each one goes.'),
    14: ('Media', 'Your social space. Post, follow other businesses and see what their customers say.'),
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: GuideStore.revision,
        builder: (context, _, __) {
          final t = _tips[section];
          final id = 'tip_$section';
          final show = t != null && GuideStore.tipsOn && !GuideStore.seenTips.contains(id);
          return AnimatedSize(
            duration: kMed,
            curve: kCurve,
            alignment: Alignment.topCenter,
            child: !show
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(id),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.primary.withValues(alpha: 0.25))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.lightbulb_rounded, size: 20, color: C.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(t.$2, style: TextStyle(fontSize: 13, height: 1.35, color: C.muted)),
                          ]),
                        ),
                        TextButton(
                          key: ValueKey('tip_ok_$section'),
                          onPressed: () => GuideStore.dismissTip(id),
                          child: Text('Got it', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOut),
                  ),
          );
        },
      );
}

const _howTo = <(IconData, String, List<String>)>[
  (Icons.person_add_alt_1_rounded, 'Add your customers', ['Open Business Phonebook.', 'Tap Add, or Import to bring in a list.', 'Put customers who should be asked into a group.']),
  (Icons.send_rounded, 'Send an invitation', ['Open a customer in the Phonebook.', 'Choose text, email, WhatsApp or QR.', 'Reminders go out by themselves if they do not reply. Set them in Automations.']),
  (Icons.videocam_rounded, 'What your customer sees', ['They open your link and agree to record.', 'They rate you, then record a video, write a review, or use an avatar if they are camera-shy.', 'They send it and see a thank-you.']),
  (Icons.verified_rounded, 'Approve a testimonial', ['Open Reviews. New videos say Waiting.', 'Open one and check it. You can edit the transcript.', 'Approve it. Nothing is public until you do.']),
  (Icons.auto_awesome_rounded, 'Make a post from a review', ['Open Create.', 'Pick a maker, or Record a video.', 'Add captions and your logo, then save or schedule it.']),
  (Icons.rocket_launch_rounded, 'Publish it', ['Open Publishing and connect an account in Connected accounts.', 'Choose where each approved video goes.', 'Put the testimonial wall on your website with Embeds.']),
  (Icons.play_circle_rounded, 'Use the Media tab', ['Post a photo, reel or story from the + button.', 'Follow other businesses and open Explore to search.', 'Your profile shows your posts, likes and Insights.']),
];

/// Help and guide: replay the tour, turn tips on or off, and short how-to cards for the real workflow.
class GuideHelpScreen extends StatefulWidget {
  const GuideHelpScreen({super.key});
  @override
  State<GuideHelpScreen> createState() => _GuideHelpScreenState();
}

class _GuideHelpScreenState extends State<GuideHelpScreen> {
  int? open;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: GuideStore.revision,
          builder: (context, _, __) => AppPage(children: [
            const BackHeader('Help and guide'),
            const Muted('New here? Take the tour, or read how each step works.'),
            const SizedBox(height: 16),
            AppCard(
              onTap: () => GuideStore.showTour(context),
              child: Row(children: [
                const GlossIcon(Icons.slideshow_rounded, Color(0xFF3E94F5), size: 46),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Take the tour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 2),
                    Muted('Four short screens, about a minute', size: 13),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(children: [
                const GlossIcon(Icons.lightbulb_rounded, Color(0xFFF2A100), size: 46),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tips on each screen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 2),
                    Muted('A short hint the first time you open a page', size: 13),
                  ]),
                ),
                Switch(key: const ValueKey('tips_switch'), value: GuideStore.tipsOn, onChanged: GuideStore.setTips),
              ]),
            ),
            const SectionHeader('How it works'),
            for (var i = 0; i < _howTo.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  key: ValueKey('howto_$i'),
                  onTap: () => setState(() => open = open == i ? null : i),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(_howTo[i].$1, color: C.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_howTo[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                      AnimatedRotation(turns: open == i ? 0.5 : 0, duration: kFast, child: Icon(Icons.keyboard_arrow_down_rounded, color: C.muted)),
                    ]),
                    AnimatedSize(
                      duration: kMed,
                      curve: kCurve,
                      alignment: Alignment.topCenter,
                      child: open != i
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                for (var s = 0; s < _howTo[i].$3.length; s++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: C.primarySoft),
                                        child: Text('${s + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.primary)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(_howTo[i].$3[s], style: const TextStyle(fontSize: 14, height: 1.4))),
                                    ]),
                                  ),
                              ]),
                            ),
                    ),
                  ]),
                ),
              ),
            const SectionHeader('Still stuck?'),
            AppCard(
              onTap: () => Navigator.of(context).pop('support'),
              child: Row(children: [
                const GlossIcon(Icons.support_agent_rounded, Color(0xFF0FA386), size: 46),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Chat with the ViewRec team', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 2),
                    Muted('Our AI assistant answers first, then a person', size: 13),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      );
}

/// Opens Help and guide from anywhere inside the Shell, and Support if that is what was chosen.
Future<void> openHelp(BuildContext context) async {
  final shell = context.findAncestorStateOfType<ShellState>();
  final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const GuideHelpScreen()));
  if (r == 'support') shell?.push(const SupportScreen());
}
