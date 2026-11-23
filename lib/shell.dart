import 'dart:ui' show ImageFilter;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './icons.dart';
import 'liquid_bar.dart';
import 'motion.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'widgets.dart';
import 'screens/overview.dart';
import 'screens/testimonials.dart';
import 'screens/create_content.dart';
import 'screens/phonebook.dart';
import 'screens/leads.dart';
import 'screens/automations.dart';
import 'screens/your_pages.dart';
import 'screens/publishing.dart';
import 'screens/connected_accounts.dart';
import 'screens/billing.dart';
import 'screens/settings.dart';
import 'screens/admin.dart';
import 'screens/additional_services.dart';
import 'screens/notifications.dart';
import 'screens/assistant.dart';
import 'screens/invite_composer.dart';
import 'screens/record.dart';
import 'screens/help.dart';

class Section {
  final String title, blurb;
  final IconData icon, iconFill;
  final Color color;
  final Widget Function(ShellState) build;
  const Section(this.title, this.blurb, this.icon, this.iconFill, this.color, this.build);
}

/// Index of the virtual "More" page (the grid of every other section).
const kMoreIndex = 13;

/// App shell: floating frosted tab bar, a quick-create button in the middle, a large page header,
/// and a "More" grid for everything that isn't a main tab.
class Shell extends StatefulWidget {
  final int initialIndex;
  const Shell({super.key, this.initialIndex = 0});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  late int index = widget.initialIndex;

  /// Sections shown directly on the tab bar.
  static const tabs = [0, 1, 4];

  late final List<Section> sections = [
    Section('Overview', 'Your proof at a glance', PIconsRegular.house, PIconsFill.house, C.primary, (s) => OverviewScreen(shell: s)),
    Section('Testimonials', 'Videos and reviews from customers', PIconsRegular.quotes, PIconsFill.quotes, const Color(0xFFFF6B8B), (s) => const TestimonialsScreen()),
    Section('Create content', 'Turn reviews into posts', PIconsRegular.magicWand, PIconsFill.magicWand, const Color(0xFFB265FF), (s) => const CreateContentScreen()),
    Section('Business Phonebook', 'Customers to ask', PIconsRegular.addressBook, PIconsFill.addressBook, const Color(0xFF2F8FE0), (s) => const PhonebookScreen()),
    Section('Leads and Requests', 'People asking for your work', PIconsRegular.handshake, PIconsFill.handshake, const Color(0xFFFF9F43), (s) => const LeadsScreen()),
    Section('Automations', 'Ask at the right moment', PIconsRegular.lightning, PIconsFill.lightning, const Color(0xFFE0A100), (s) => const AutomationsScreen()),
    Section('Your pages', 'Review page, listing, website', PIconsRegular.browsers, PIconsFill.browsers, const Color(0xFF0FB58A), (s) => const YourPagesScreen()),
    Section('Publishing', 'Posts and schedule', PIconsRegular.rocketLaunch, PIconsFill.rocketLaunch, const Color(0xFF7C5CFF), (s) => const PublishingScreen()),
    Section('Connected accounts', 'Google, Facebook and more', PIconsRegular.shareNetwork, PIconsFill.shareNetwork, const Color(0xFF3B82F6), (s) => const ConnectedAccountsScreen()),
    Section('Plan & billing', 'Your plan and invoices', PIconsRegular.creditCard, PIconsFill.creditCard, const Color(0xFF14B8A6), (s) => const BillingScreen()),
    Section('Settings', 'Profile, branding, privacy', PIconsRegular.gear, PIconsFill.gear, const Color(0xFF8E8EA8), (s) => const SettingsScreen()),
    Section('Admin control', 'Staff tools', PIconsRegular.shieldCheck, PIconsFill.shieldCheck, const Color(0xFFEF4444), (s) => const AdminScreen()),
    Section('Additional services', 'Rewards, ads, referrals', PIconsRegular.stack, PIconsFill.stack, const Color(0xFFEC4899), (s) => const AdditionalServicesScreen()),
    Section('More', 'Everything else', PIconsRegular.dotsNine, PIconsFill.dotsNine, C.primary, (s) => _MoreGrid(shell: s)),
  ];

  void goTo(int i) {
    if (i == index) return;
    HapticFeedback.selectionClick();
    setState(() => index = i);
  }

  void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  /// Which of the five bar slots the water droplet sits behind.
  int get _slot => switch (index) { 0 => 0, 1 => 1, 4 => 3, _ => 4 };

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 5 ? 'Good night' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final sec = sections[index];
    return Scaffold(
      body: Stack(children: [
        Column(children: [
          SafeArea(bottom: false, child: _header(sec)),
          Expanded(
            child: PageTransitionSwitcher(
              duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 420),
              transitionBuilder: (child, anim, secAnim) => FadeThroughTransition(animation: anim, secondaryAnimation: secAnim, fillColor: Colors.transparent, child: child),
              child: KeyedSubtree(key: ValueKey(index), child: sec.build(this)),
            ),
          ),
        ]),
        _bar(context),
      ]),
    );
  }

  // ---------- header ----------
  Widget _round(Widget icon, VoidCallback onTap, {int? badge}) => Pressable(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.border), boxShadow: C.shadow),
            child: Center(child: icon),
          ),
          if (badge != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: C.rec, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.bg, width: 2)),
                child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]),
      );

  Widget _header(Section sec) {
    final isTab = tabs.contains(index) || index == kMoreIndex;
    final overview = index == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!isTab) ...[
          _round(Icon(PIconsBold.caretLeft, size: 18, color: C.text), () => goTo(kMoreIndex)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (overview) Text(_greeting, style: TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
            AnimatedSwitcher(
              duration: kMed,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c)),
              child: Text(
                overview ? 'Hartley Roofing' : sec.title,
                key: ValueKey(sec.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        _round(
          AnimatedSwitcher(
            duration: kMed,
            transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
            child: Icon(C.dark ? PIconsRegular.sun : PIconsRegular.moon, key: ValueKey(C.dark), size: 19, color: C.text),
          ),
          ThemeController.instance.toggle,
        ),
        const SizedBox(width: 10),
        _round(Icon(PIconsRegular.bell, size: 19, color: C.text), () => push(const NotificationsScreen()), badge: 3),
      ]),
    );
  }

  // ---------- floating bar ----------
  Widget _tab(int section, String label) {
    final sel = index == section || (section == kMoreIndex && !tabs.contains(index));
    final s = sections[section];
    return Expanded(
      child: Pressable(
        onTap: () => goTo(section),
        scale: 0.92,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: kMed,
            curve: kCurve,
            width: 46,
            height: 30,
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(15)),
            child: Center(
              child: AnimatedSwitcher(
                duration: kFast,
                child: Icon(sel ? s.iconFill : s.icon, key: ValueKey(sel), size: 22, color: sel ? C.primary : C.muted),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: kMed,
            style: TextStyle(fontFamily: 'Manrope', fontSize: 10.5, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? C.primary : C.muted),
            child: Text(label),
          ),
        ]),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom + 12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark ? 0.5 : 0.12), blurRadius: 32, offset: const Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: C.surface.withValues(alpha: C.dark ? 0.78 : 0.9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: C.dark ? const Color(0x1FFFFFFF) : const Color(0xFFE6E6F1)),
              ),
              child: LiquidNavBar(selected: _slot, children: [
                _tab(0, 'Home'),
                _tab(1, 'Reviews'),
                Expanded(child: Center(child: _centerButton())),
                _tab(4, 'Inbox'),
                _tab(kMoreIndex, 'More'),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerButton() => Pressable(
        onTap: _quickCreate,
        scale: 0.9,
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9378FF), Color(0xFF6A4CF0)]),
              boxShadow: C.glow,
            ),
            child: const Icon(PIconsBold.plus, color: Colors.white, size: 24),
          ),
        ),
      );

  void _quickCreate() {
    final nav = Navigator.of(context);
    void closeThen(VoidCallback f) {
      nav.pop();
      f();
    }

    final actions = <(IconData, String, Color, VoidCallback)>[
      (PIconsRegular.paperPlaneTilt, 'Send invitation', C.primary, () => closeThen(() => push(const InviteComposerScreen()))),
      (PIconsRegular.link, 'Get video link', const Color(0xFF3B82F6), () => closeThen(() => showVideoLinkSheet(context))),
      (PIconsRegular.videoCamera, 'Preview recording', C.rec, () => closeThen(() => push(const RecordScreen()))),
      (PIconsRegular.magicWand, 'Create a post', const Color(0xFFB265FF), () => closeThen(() => goTo(2))),
      (PIconsRegular.userPlus, 'Add a contact', const Color(0xFF0FB58A), () => closeThen(() => goTo(3))),
      (PIconsRegular.sparkle, 'Ask assistant', const Color(0xFFE0A100), () => closeThen(() => push(const AssistantScreen()))),
    ];
    showSheet(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Quick create'),
        const SizedBox(height: 4),
        const Muted('Start something in one tap.', size: 13),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [
            for (var i = 0; i < actions.length; i++)
              Pressable(
                onTap: actions[i].$4,
                child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(color: actions[i].$3.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                    child: Icon(actions[i].$1, color: actions[i].$3, size: 27),
                  ),
                  const SizedBox(height: 8),
                  Text(actions[i].$2, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
                ]).reveal(context, i, 0.12),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}

/// The "More" page: every section that isn't a main tab, as a grid of tiles.
class _MoreGrid extends StatelessWidget {
  final ShellState shell;
  const _MoreGrid({required this.shell});

  @override
  Widget build(BuildContext context) {
    // (section index) groups
    const groups = <(String, List<int>)>[
      ('Grow', [2, 6, 7, 8]),
      ('Customers', [3, 5]),
      ('Account', [9, 10, 12, 11]),
    ];
    var n = 0;
    return AppPage(reveal: false, children: [
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(g.$1.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: C.muted)),
        ).reveal(context, n++, 0.05),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: [
            for (final i in g.$2)
              _tile(context, shell.sections[i], () => shell.goTo(i)).reveal(context, n++, 0.1),
          ],
        ),
        const SizedBox(height: 14),
      ],
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          Tile(icon: PIconsRegular.question, title: 'Help & FAQs', onTap: () => shell.push(const HelpScreen())),
          Tile(icon: PIconsRegular.sparkle, title: 'Ask the assistant', onTap: () => shell.push(const AssistantScreen())),
          Tile(
            icon: PIconsRegular.signOut,
            iconColor: C.rec,
            title: 'Sign out',
            divider: false,
            onTap: () => Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst),
          ),
        ]),
      ).reveal(context, n++, 0.06),
    ]);
  }

  Widget _tile(BuildContext context, Section s, VoidCallback onTap) => Pressable(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rLg), border: Border.all(color: C.border), boxShadow: C.shadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [s.color.withValues(alpha: 0.95), s.color.withValues(alpha: 0.65)]),
                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(s.iconFill, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.2)),
            const SizedBox(height: 3),
            Text(s.blurb, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

/// "Get video link" sheet: copy / SMS / email / WhatsApp / preview / custom invitation.
void showVideoLinkSheet(BuildContext context) {
  const link = 'https://viewrec.com/r/demo';
  showSheet(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H2('Your video link'),
      const SizedBox(height: 4),
      const Muted('Share this one link. Customers record from their own phone, with no account and no download.', size: 13),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
        child: Row(children: [
          Icon(PIconsRegular.link, size: 18, color: C.muted),
          const SizedBox(width: 10),
          const Expanded(child: Text(link, style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
        ]),
      ),
      const SizedBox(height: 14),
      AppButton('Copy video link', icon: PIconsRegular.copy, onTap: () {
        Clipboard.setData(const ClipboardData(text: link));
        Navigator.pop(context);
        showMsg(context, 'Link copied');
      }),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: AppButton('SMS', icon: PIconsRegular.chatText, style: BtnStyle.ghost, small: true, onTap: () => Navigator.pop(context))),
        const SizedBox(width: 8),
        Expanded(child: AppButton('Email', icon: PIconsRegular.envelopeSimple, style: BtnStyle.ghost, small: true, onTap: () => Navigator.pop(context))),
        const SizedBox(width: 8),
        Expanded(child: AppButton('WhatsApp', icon: PIconsRegular.whatsappLogo, style: BtnStyle.ghost, small: true, onTap: () => Navigator.pop(context))),
      ]),
      const SizedBox(height: 8),
      AppButton('Send custom invitation', icon: PIconsRegular.sparkle, onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteComposerScreen()));
      }),
    ]),
  );
}
