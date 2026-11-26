import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import './icons.dart';
import 'liquid_bar.dart';
import 'motion.dart';
import 'order_store.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'widgets.dart';
import 'screens/overview.dart';
import 'screens/search.dart';
import 'screens/testimonials.dart';
import 'screens/create_content.dart';
import 'screens/section_tabs.dart';
import 'screens/leads.dart';
import 'screens/your_pages.dart';
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
import 'screens/inbox.dart';
import 'screens/media.dart';
import 'screens/media_widgets.dart';
import 'screens/gallery.dart';
import 'screens/templates.dart';
import 'screens/verification.dart';
import 'screens/review_requests.dart';
import 'screens/referrals.dart';
import 'screens/video_settings.dart';
import 'screens/support_chat.dart';
import 'screens/security.dart';
import 'screens/marketing_email.dart';
import 'screens/workspaces.dart';
import 'repo.dart';

class Section {
  final String title, blurb;
  final IconData icon, iconFill;
  final Color color;
  final Widget Function(ShellState) build;
  const Section(this.title, this.blurb, this.icon, this.iconFill, this.color, this.build);
}

/// Index of the virtual "More" page (the grid of every other section).
const kMoreIndex = 13;

/// Index of the Media tab (stories and reels).
const kMediaIndex = 14;

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
  int unread = 0; // new conversations, shown on the message icon
  int unreadNotifications = 0; // shown on the bell
  bool _exitArmed = false; // after one Back press on Home, a second one within 2 seconds leaves the app
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _loadUnreadNotifications() {
    repo.notifications().then((l) {
      if (mounted) setState(() => unreadNotifications = l.where((n) => !n.read).length);
    }).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    repo.leads().then((l) {
      if (mounted) setState(() => unread = l.where((x) => x.status == 'new').length);
    }).catchError((_) {});
  }

  /// Sections shown directly on the tab bar.
  static const tabs = [0, 1, kMediaIndex];

  late final List<Section> sections = [
    Section('Overview', 'Your proof at a glance', PIconsRegular.house, PIconsFill.house, C.primary, (s) => OverviewScreen(shell: s)),
    Section('Testimonials', 'Videos and reviews from customers', PIconsRegular.quotes, PIconsFill.quotes, const Color(0xFFFF8A80), (s) => const TestimonialsScreen()),
    Section('Create your posting', 'Turn reviews into posts', PIconsRegular.magicWand, PIconsFill.magicWand, const Color(0xFF1FC9A4), (s) => const CreateContentScreen()),
    Section('Business Phonebook', 'Customers to ask', PIconsRegular.addressBook, PIconsFill.addressBook, const Color(0xFF3E94F5), (s) => const PhonebookTabs()),
    Section('Leads and Requests', 'People asking for your work', PIconsRegular.handshake, PIconsFill.handshake, const Color(0xFFFFC21A), (s) => const LeadsScreen()),
    Section('Automations', 'Ask at the right moment', PIconsRegular.lightning, PIconsFill.lightning, const Color(0xFFF2A100), (s) => const AutomationsTabs()),
    Section('Your pages', 'Review page, listing, website', PIconsRegular.browsers, PIconsFill.browsers, const Color(0xFF1FC9A4), (s) => const YourPagesScreen()),
    Section('Publishing', 'Posts and schedule', PIconsRegular.rocketLaunch, PIconsFill.rocketLaunch, const Color(0xFF0B5FC4), (s) => const PublishingTabs()),
    Section('Connected accounts', 'Google, Facebook and more', PIconsRegular.shareNetwork, PIconsFill.shareNetwork, const Color(0xFF3E94F5), (s) => const ConnectedAccountsScreen()),
    Section('Plan & billing', 'Your plan and invoices', PIconsRegular.creditCard, PIconsFill.creditCard, const Color(0xFF0FA386), (s) => const BillingScreen()),
    Section('Settings', 'Profile, branding, privacy', PIconsRegular.gear, PIconsFill.gear, const Color(0xFF8A9BB8), (s) => const SettingsScreen()),
    Section('Admin control', 'Staff tools', PIconsRegular.shieldCheck, PIconsFill.shieldCheck, const Color(0xFFE4513F), (s) => const AdminScreen()),
    Section('Additional services', 'Rewards, ads, referrals', PIconsRegular.stack, PIconsFill.stack, const Color(0xFFFF6B5E), (s) => const AdditionalServicesScreen()),
    Section('More', 'Everything else', PIconsRegular.dotsNine, PIconsFill.dotsNine, C.primary, (s) => _MoreGrid(shell: s)),
    Section('Media', 'Stories and reels', PIconsRegular.playCircle, PIconsFill.playCircle, const Color(0xFFFF6B5E), (s) => const MediaScreen()),
    Section('Gallery', 'Your videos, pictures and documents', Icons.photo_library_outlined, Icons.photo_library_rounded, const Color(0xFF3E94F5), (s) => const GalleryScreen()),
    Section('Contact bundles', 'Email a group of customers', Icons.groups_outlined, Icons.groups_rounded, const Color(0xFF0B5FC4), (s) => const PhonebookTabs(initial: 2)),
    Section('Calendar', 'What is going out and when', Icons.calendar_month_outlined, Icons.calendar_month_rounded, const Color(0xFF0FA386), (s) => const PhonebookTabs(initial: 3)),
    Section('Review templates', 'Questions customers answer', Icons.quiz_outlined, Icons.quiz_rounded, const Color(0xFFF2A100), (s) => const TemplatesScreen()),
    Section('Verification', 'Get your blue tick', Icons.verified_outlined, Icons.verified_rounded, const Color(0xFF3E94F5), (s) => const VerificationScreen()),
    Section('Review requests', 'People asking to review you', Icons.how_to_reg_outlined, Icons.how_to_reg_rounded, const Color(0xFFFF8A80), (s) => const ReviewRequestsScreen()),
    Section('Referrals', 'Earn credit for new businesses', Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, const Color(0xFFFF6B5E), (s) => const ReferralHubScreen()),
    Section('Video settings', 'Subtitles and watermark', Icons.closed_caption_outlined, Icons.closed_caption_rounded, const Color(0xFF8A9BB8), (s) => const VideoSettingsScreen()),
    Section('Embeds', 'Show reviews on your website', Icons.code_outlined, Icons.code_rounded, const Color(0xFF1FC9A4), (s) => const PublishingTabs(initial: 2)),
    Section('Support', 'Chat with the ViewRec team', Icons.support_agent_outlined, Icons.support_agent_rounded, const Color(0xFF1FC9A4), (s) => const SupportChatScreen(avoidTabBar: true)),
    Section('Security', 'Two-step sign-in and devices', Icons.shield_outlined, Icons.shield_rounded, const Color(0xFFE4513F), (s) => const SecurityScreen()),
    Section('Marketing email', 'Write to your customers', Icons.campaign_outlined, Icons.campaign_rounded, const Color(0xFFFFC21A), (s) => const MarketingEmailScreen()),
    Section('Workspaces', 'Switch between businesses', Icons.swap_horizontal_circle_outlined, Icons.swap_horizontal_circle_rounded, const Color(0xFF3E94F5), (s) => const WorkspacesScreen()),
  ];

  void goTo(int i) {
    if (i == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      index = i;
      scrolled = false;
    });
  }

  bool scrolled = false;

  Future<void> push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  /// Which of the five bar slots the water droplet sits behind.
  int get _slot => switch (index) { 0 => 0, 1 => 1, kMediaIndex => 3, _ => 4 };

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 5 ? 'Good night' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final sec = sections[index];
    final typing = MediaQuery.of(context).viewInsets.bottom > 0; // the keyboard is up: the tab bar steps aside
    return PopScope(
      // The phone's Back button walks back through the app instead of closing it:
      // a section opened from More goes back to More, a tab goes back to Home, and Home asks twice before leaving.
      canPop: index == 0 && _exitArmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          goTo(tabs.contains(index) || index == kMoreIndex ? 0 : kMoreIndex);
          return;
        }
        setState(() => _exitArmed = true);
        showMsg(context, 'Press Back again to leave the app');
        _exitTimer?.cancel();
        _exitTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _exitArmed = false);
        });
      },
      child: Scaffold(
      body: Stack(children: [
        Column(children: [
          // The header takes the status-bar space once; pages below must not add it again.
          AnimatedContainer(
            duration: kMed,
            curve: kCurve,
            decoration: BoxDecoration(
              color: scrolled ? C.bg.withValues(alpha: 0.94) : Colors.transparent,
              border: Border(bottom: BorderSide(color: scrolled ? C.border : Colors.transparent)),
              boxShadow: scrolled && !C.dark ? const [BoxShadow(color: Color(0x0F1B1550), blurRadius: 16, offset: Offset(0, 6))] : null,
            ),
            child: SafeArea(bottom: false, child: _header(sec)),
          ),
          Expanded(
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
                  final s = n.metrics.pixels > 8;
                  if (s != scrolled) setState(() => scrolled = s);
                }
                return false;
              },
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: PageTransitionSwitcher(
                  duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 420),
                  transitionBuilder: (child, anim, secAnim) => FadeThroughTransition(animation: anim, secondaryAnimation: secAnim, fillColor: Colors.transparent, child: child),
                  child: KeyedSubtree(key: ValueKey(index), child: sec.build(this)),
                ),
              ),
            ),
          ),
        ]),
        if (!typing) _bar(context),
      ]),
    ));
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: FadeTransition(opacity: a, child: c)),
                  child: Text('$badge', key: ValueKey(badge), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
        ]),
      );

  Widget _header(Section sec) {
    final isTab = tabs.contains(index) || index == kMoreIndex;
    final overview = index == 0;
    final media = index == kMediaIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!isTab) ...[
          _round(Icon(PIconsBold.caretLeft, size: 18, color: C.text), () => goTo(kMoreIndex)),
          const SizedBox(width: 12),
        ],
        if (media) ...[
          _round(Icon(PIconsBold.plus, size: 20, color: C.text), () => showCreateSheet(context)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (overview) Text(_greeting, style: TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
            AnimatedSwitcher(
              duration: kMed,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c)),
              child: FittedBox(
                key: ValueKey(sec.title),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  overview ? 'Hartley Roofing' : sec.title,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        _round(Icon(Icons.search_rounded, size: 21, color: C.text), () => push(SearchScreen(shell: this))),
        const SizedBox(width: 10),
        _round(
          reduceMotion(context)
              ? Icon(PIconsRegular.bell, size: 19, color: C.text)
              : Icon(PIconsRegular.bell, size: 19, color: C.text).animate(key: const ValueKey('bell'), delay: 1400.ms).shake(hz: 4, rotation: 0.28, duration: 700.ms, curve: Curves.easeOut),
          () => push(NotificationsScreen(shell: this)).then((_) => _loadUnreadNotifications()),
          badge: unreadNotifications > 0 ? unreadNotifications : null,
        ),
        const SizedBox(width: 10),
        _round(Icon(Icons.chat_bubble_outline_rounded, size: 19, color: C.text), () => push(const InboxScreen()).then((_) => repo.leads().then((l) {
              if (mounted) setState(() => unread = l.where((x) => x.status == 'new').length);
            }).catchError((_) {})), badge: unread > 0 ? unread : null),
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
        scale: 0.94,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // The chosen icon floats up into the liquid bubble.
          AnimatedSlide(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            offset: Offset(0, sel ? -0.7 : 0),
            child: SizedBox(
              width: 46,
              height: 30,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Icon(sel ? s.iconFill : s.icon, key: ValueKey(sel), size: sel ? 25 : 22, color: sel ? Colors.white : C.muted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 500),
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? C.primary : C.muted),
            child: Text(label),
          ),
        ]),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 14,
      right: 14,
      bottom: bottom + 4,
      child: LiquidNavBar(selected: _slot, children: [
        _tab(0, 'Home'),
        _tab(1, 'Reviews'),
        Expanded(child: Center(child: _centerButton())),
        _tab(kMediaIndex, 'Media'),
        _tab(kMoreIndex, 'More'),
      ]),
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
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E94F5), Color(0xFF0B5FC4)]),
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
      (PIconsRegular.link, 'Get video link', const Color(0xFF3E94F5), () => closeThen(() => showVideoLinkSheet(context))),
      (PIconsRegular.videoCamera, 'Preview recording', C.rec, () => closeThen(() => push(const RecordScreen()))),
      (PIconsRegular.magicWand, 'Create a post', const Color(0xFF1FC9A4), () => closeThen(() => goTo(2))),
      (PIconsRegular.userPlus, 'Add a contact', const Color(0xFF1FC9A4), () => closeThen(() => goTo(3))),
      (Icons.chat_bubble_outline_rounded, 'Ask assistant', const Color(0xFFF2A100), () => closeThen(() => push(const AssistantScreen()))),
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
                  GlossIcon(actions[i].$1, actions[i].$3, size: 62),
                  const SizedBox(height: 8),
                  Text(actions[i].$2, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
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
class _MoreGrid extends StatefulWidget {
  final ShellState shell;
  const _MoreGrid({required this.shell});
  @override
  State<_MoreGrid> createState() => _MoreGridState();
}

class _MoreGridState extends State<_MoreGrid> {
  ShellState get shell => widget.shell;

  // The first group follows the website's menu, in the same order. The second holds what only the app has.
  // Groups, Calendar, Email a group and Embeds live inside Business Phonebook and Publishing, as on the website.
  static const _defaults = <(String, String, List<int>)>[
    ('menu', 'Menu', [2, 15, 3, 4, 5, 6, 7, 8, 9, 10, 12, 11]),
    ('extras', 'Only in the app', [18, 20, 22, 24]),
  ];
  late final Map<String, List<int>> orders = {for (final g in _defaults) g.$1: List.of(g.$3)};

  @override
  void initState() {
    super.initState();
    for (final g in _defaults) {
      OrderStore.load('more_${g.$1}').then((saved) {
        if (saved != null && mounted) setState(() => orders[g.$1] = [for (final s in applyOrder([for (final i in g.$3) '$i'], saved, (s) => s)) int.parse(s)]);
      });
    }
  }

  void _move(String group, String from, String to) {
    final ids = movedBefore([for (final i in orders[group]!) '$i'], from, to);
    setState(() => orders[group] = [for (final s in ids) int.parse(s)]);
    OrderStore.save('more_$group', ids);
  }

  void _reset(String group) {
    setState(() => orders[group] = List.of(_defaults.firstWhere((g) => g.$1 == group).$3));
    OrderStore.clear('more_$group');
  }

  @override
  Widget build(BuildContext context) {
    var n = 0;
    return AppPage(reveal: false, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: C.primarySoft),
              child: Icon(Icons.contrast_rounded, size: 20, color: C.primary),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Appearance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 2),
                Muted('Light, dark, or follow your phone', size: 12.5),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Pills(const ['Automatic', 'Light', 'Dark'], ThemeController.instance.mode.index, (i) => ThemeController.instance.setMode(AppThemeMode.values[i])),
        ]),
      ).reveal(context, n++, 0.05),
      const SizedBox(height: 8),
      for (final g in _defaults) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Row(children: [
            Expanded(child: Text(g.$2.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: C.muted))),
            if (orders[g.$1]!.join(',') != g.$3.join(','))
              GestureDetector(
                onTap: () => _reset(g.$1),
                child: Text('Reset order', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.primary)),
              )
            else
              Text('Press and hold to move', style: TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ).reveal(context, n++, 0.05),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: MediaQuery.textScalerOf(context).scale(1) > 1.15 ? 0.9 : 1.02,
          children: [
            for (final i in orders[g.$1]!)
              ReorderItem(
                key: ValueKey('more_$i'),
                group: g.$1,
                id: '$i',
                radius: rLg,
                onMove: (from, to) => _move(g.$1, from, to),
                child: _tile(context, shell.sections[i], () => i == 24 ? shell.push(const SupportScreen()) : shell.goTo(i)),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          Tile(icon: PIconsRegular.question, title: 'Help & FAQs', onTap: () => shell.push(const HelpScreen())),
          Tile(icon: Icons.chat_bubble_outline_rounded, title: 'Ask the assistant', onTap: () => shell.push(const AssistantScreen())),
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
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [s.color.withValues(alpha: 0.95), s.color.withValues(alpha: 0.65)]),
                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(s.iconFill, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.2)),
            const SizedBox(height: 3),
            Text(s.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w500)),
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
      AppButton('Send custom invitation', icon: PIconsRegular.paperPlaneTilt, onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteComposerScreen()));
      }),
    ]),
  );
}
