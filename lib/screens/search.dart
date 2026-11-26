import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data.dart';
import '../media_data.dart';
import '../models.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'admin.dart';
import 'contact_detail.dart';
import 'help.dart';
import 'inbox.dart';
import 'invitations.dart';
import 'lead_thread.dart';
import 'media_profile.dart';
import 'notifications.dart';
import 'publishing_where.dart';
import 'referrals.dart';
import 'security.dart';
import 'settings.dart';
import 'settings_extra.dart';
import 'support_chat.dart';
import 'verification.dart';
import 'video_detail.dart';
import 'workspaces.dart';

/// One place in the app you can jump to.
class _Page {
  final String title, where, keywords;
  final IconData icon;
  final void Function(BuildContext, ShellState) open;
  const _Page(this.title, this.where, this.icon, this.keywords, this.open);
}

void _tab(ShellState s, int i) => s.goTo(i);
Future<void> _push(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
Future<void> _sub(BuildContext c, String title, Widget w) => _push(c, SubPageShell(title: title, child: w));

final _pages = <_Page>[
  _Page('Overview', 'Home', Icons.home_rounded, 'home dashboard stats checklist', (c, s) => _tab(s, 0)),
  _Page('Testimonials', 'Menu', Icons.format_quote_rounded, 'videos reviews approve customers recordings', (c, s) => _tab(s, 1)),
  _Page('Create your posting', 'Menu', Icons.auto_fix_high_rounded, 'post quote card clip story carousel record video script captions logo template draft', (c, s) => _tab(s, 2)),
  _Page('Gallery', 'Menu', Icons.photo_library_rounded, 'files pictures videos documents folders upload', (c, s) => _tab(s, 15)),
  _Page('Business Phonebook', 'Menu', Icons.contacts_rounded, 'customers contacts people add import export', (c, s) => _tab(s, 3)),
  _Page('Invitations sent', 'Business Phonebook', Icons.mark_email_read_rounded, 'invite invited reminder remind nudges waiting', (c, s) => _sub(c, 'Invitations sent', const InvitationsScreen())),
  _Page('Groups', 'Business Phonebook', Icons.groups_rounded, 'bundle group email offer approach', (c, s) => _tab(s, 16)),
  _Page('Calendar', 'Business Phonebook', Icons.calendar_month_rounded, 'reminder schedule dates what is going out', (c, s) => _tab(s, 17)),
  _Page('Leads and Requests', 'Menu', Icons.handshake_rounded, 'requests enquiries inbox messages people asking', (c, s) => _tab(s, 4)),
  _Page('Automations', 'Menu', Icons.bolt_rounded, 'remind me reminder automatic ask after job polite hours email a group', (c, s) => _tab(s, 5)),
  _Page('Your pages', 'Menu', Icons.web_rounded, 'review page listing business page qr link website', (c, s) => _tab(s, 6)),
  _Page('Publishing', 'Menu', Icons.rocket_launch_rounded, 'post queue history schedule social facebook instagram', (c, s) => _tab(s, 7)),
  _Page('Where they go', 'Publishing', Icons.alt_route_rounded, 'channels webhook destination youtube tiktok pinterest linkedin threads google business waiting to post', (c, s) => _sub(c, 'Where they go', const PublishingWhereScreen())),
  _Page('On your website', 'Publishing', Icons.code_rounded, 'embed embeds script wall widget reviews on website', (c, s) => _tab(s, 23)),
  _Page('Connected accounts', 'Menu', Icons.share_rounded, 'google facebook instagram connect link accounts sign in', (c, s) => _tab(s, 8)),
  _Page('Plan & billing', 'Menu', Icons.credit_card_rounded, 'plan invoice payment card trial upgrade pro price', (c, s) => _tab(s, 9)),
  _Page('Settings', 'Menu', Icons.settings_rounded, 'profile preferences account', (c, s) => _tab(s, 10)),
  _Page('Admin control', 'Menu', Icons.admin_panel_settings_rounded, 'staff team access', (c, s) => _tab(s, 11)),
  _Page('Additional services', 'Menu', Icons.layers_rounded, 'rewards ads referral agent managed', (c, s) => _tab(s, 12)),
  _Page('Media', 'Tab', Icons.play_circle_rounded, 'stories reels feed follow businesses', (c, s) => _tab(s, 14)),
  _Page('Review templates', 'Only in the app', Icons.quiz_rounded, 'questions customers answer script', (c, s) => _tab(s, 18)),
  _Page('Review requests', 'Only in the app', Icons.how_to_reg_rounded, 'people asking to review you approve decline', (c, s) => _tab(s, 20)),
  _Page('Video settings', 'Only in the app', Icons.closed_caption_rounded, 'subtitles watermark captions', (c, s) => _tab(s, 22)),
  _Page('Support', 'Only in the app', Icons.support_agent_rounded, 'help chat viewrec team contact', (c, s) => _push(c, const SupportScreen())),
  _Page('Inbox', 'Header', Icons.chat_bubble_outline_rounded, 'messages conversations replies', (c, s) => _push(c, const InboxScreen())),
  _Page('Notifications', 'Header', Icons.notifications_none_rounded, 'alerts bell', (c, s) => _push(c, const NotificationsScreen())),
  _Page('Verification', 'Additional services', Icons.verified_rounded, 'blue tick documents verified business', (c, s) => _sub(c, 'Verification', const VerificationScreen())),
  _Page('Referrals', 'Additional services', Icons.card_giftcard_rounded, 'refer earn credit friends', (c, s) => _sub(c, 'Referrals', const ReferralHubScreen())),
  _Page('Business profile', 'Settings', Icons.storefront_rounded, 'name category phone email website logo about', (c, s) => _push(c, const BusinessProfileScreen())),
  _Page('Branding & invitations', 'Settings', Icons.palette_rounded, 'logo colour wording message accent', (c, s) => _push(c, const BrandingScreen())),
  _Page('Team members', 'Settings', Icons.group_rounded, 'invite teammate role remove staff', (c, s) => _sub(c, 'Team & access', const AdminScreen())),
  _Page('Opt-out list', 'Settings', Icons.block_rounded, 'unsubscribe stop never contact', (c, s) => _push(c, const OptOutsScreen())),
  _Page('Notification settings', 'Settings', Icons.tune_rounded, 'alerts push email text weekly summary', (c, s) => _push(c, const NotificationPrefsScreen())),
  _Page('Language & region', 'Settings', Icons.language_rounded, 'language time zone date format country', (c, s) => _push(c, const LanguageRegionScreen())),
  _Page('Password & sign-in', 'Settings', Icons.lock_outline_rounded, 'password change two-step security', (c, s) => _push(c, const PasswordSignInScreen())),
  _Page('Security & devices', 'Settings', Icons.shield_rounded, 'two-step devices sign out other devices', (c, s) => _sub(c, 'Security', const SecurityScreen())),
  _Page('Data & privacy', 'Settings', Icons.privacy_tip_rounded, 'export delete account data gdpr', (c, s) => _push(c, const DataPrivacyScreen())),
  _Page('Blocked accounts', 'Settings', Icons.block_rounded, 'block unblock media businesses', (c, s) => _push(c, const BlockedAccountsScreen())),
  _Page('Switch business', 'Settings', Icons.swap_horizontal_circle_rounded, 'workspace workspaces businesses', (c, s) => _sub(c, 'Workspaces', const WorkspacesScreen())),
  _Page('Help & FAQs', 'Support', Icons.help_outline_rounded, 'questions answers how do i', (c, s) => _push(c, const HelpScreen())),
];

/// Search across the whole app: pages and settings, customers, testimonials, requests, groups, businesses in Media and help answers.
class SearchScreen extends StatefulWidget {
  final ShellState shell;
  const SearchScreen({super.key, required this.shell});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final input = TextEditingController();
  final focus = FocusNode();
  String q = '';
  List<Customer> customers = [];
  List<Video> videos = [];
  List<Lead> leads = [];
  List<Bundle> groups = [];
  List<Reel> reels = [];
  List<String> recent = [];

  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => recent = p.getStringList(_recentKey) ?? []);
    }).catchError((_) {});
  }

  /// Each list is loaded on its own, so one that fails does not hide the others.
  Future<void> _load() async {
    Future<void> go<T>(Future<T> f, void Function(T) set) async {
      try {
        final v = await f;
        if (mounted) setState(() => set(v));
      } catch (_) {}
    }

    await Future.wait([
      go(repo.customers(), (v) => customers = v),
      go(repo.videos(), (v) => videos = v),
      go(repo.leads(), (v) => leads = v),
      go(webRepo.bundles(), (v) => groups = v),
      go(repo.reels(), (v) => reels = v),
    ]);
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _remember(String text) async {
    final t = text.trim();
    if (t.length < 2) return;
    final next = [t, ...recent.where((r) => r.toLowerCase() != t.toLowerCase())].take(6).toList();
    setState(() => recent = next);
    try {
      (await SharedPreferences.getInstance()).setStringList(_recentKey, next);
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => recent = []);
    try {
      (await SharedPreferences.getInstance()).remove(_recentKey);
    } catch (_) {}
  }

  List<String> get _words => q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Every word must appear somewhere in [text].
  bool _hit(String text) {
    final t = text.toLowerCase();
    return _words.every(t.contains);
  }

  int _score(_Page p) {
    final t = p.title.toLowerCase();
    if (!_words.every((w) => t.contains(w) || p.keywords.contains(w) || p.where.toLowerCase().contains(w))) return 0;
    if (t.startsWith(q.toLowerCase().trim())) return 3;
    if (_words.every(t.contains)) return 2;
    return 1;
  }

  void _go(VoidCallback open) {
    _remember(q);
    open();
  }

  Widget _section(String title, List<Widget> rows) => rows.isEmpty
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 16, 0, 8), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: C.muted))),
          AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), child: Column(children: rows)),
        ]);

  Widget _row(Widget leading, String title, String sub, VoidCallback onTap, {bool last = false}) => Tile(
        icon: Icons.circle,
        title: title,
        subtitle: sub.isEmpty ? null : sub,
        divider: !last,
        onTap: onTap,
        leading: SizedBox(width: 42, height: 42, child: Center(child: leading)),
      );

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final pages = _pages.map((p) => (p, _score(p))).where((e) => e.$2 > 0).toList()..sort((a, b) => b.$2 - a.$2);
    final people = q.isEmpty ? <Customer>[] : customers.where((c) => _hit('${c.name} ${c.job} ${c.phone}')).take(5).toList();
    final reviews = q.isEmpty ? <Video>[] : videos.where((v) => _hit('${v.name} ${v.job} ${v.quote}')).take(5).toList();
    final requests = q.isEmpty ? <Lead>[] : leads.where((l) => _hit('${l.name} ${l.service} ${l.message}')).take(5).toList();
    final grp = q.isEmpty ? <Bundle>[] : groups.where((g) => _hit('${g.name} ${g.note}')).take(5).toList();
    final seen = <String>{};
    final biz = q.isEmpty ? <Reel>[] : reels.where((r) => _hit('${r.business} ${r.handle} ${r.category}') && seen.add(r.businessId)).take(5).toList();
    final help = q.isEmpty ? <(String, String)>[] : HelpScreen.faqs.where((f) => _hit('${f.$1} ${f.$2}')).take(4).toList();
    final nothing = q.isNotEmpty && pages.isEmpty && people.isEmpty && reviews.isEmpty && requests.isEmpty && grp.isEmpty && biz.isEmpty && help.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
            child: Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, color: C.text)),
              Expanded(
                child: TextField(
                  controller: input,
                  focusNode: focus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => q = v.trim()),
                  onSubmitted: _remember,
                  decoration: InputDecoration(
                    hintText: 'Search the app',
                    hintStyle: TextStyle(color: C.muted),
                    prefixIcon: Icon(Icons.search_rounded, color: C.muted),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
                            onPressed: () {
                              input.clear();
                              setState(() => q = '');
                            },
                          ),
                    filled: true,
                    fillColor: C.dark ? C.surface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
              children: [
                if (q.isEmpty) ...[
                  if (recent.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                      child: Row(children: [
                        Expanded(child: Text('RECENT', style: TextStyle(fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: C.muted))),
                        GestureDetector(onTap: _clearRecent, child: Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.primary))),
                      ]),
                    ),
                    Wrap(children: [
                      for (final r in recent)
                        AppChip(r, active: false, onTap: () {
                          input.text = r;
                          input.selection = TextSelection.collapsed(offset: r.length);
                          setState(() => q = r);
                        }),
                    ]),
                  ],
                  Padding(padding: const EdgeInsets.fromLTRB(4, 18, 0, 6), child: Text('TRY SEARCHING FOR', style: TextStyle(fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: C.muted))),
                  Wrap(children: [
                    for (final s in const ['reminder', 'invoice', 'embed', 'password', 'logo', 'team', 'export', 'verification'])
                      AppChip(s, active: false, onTap: () {
                        input.text = s;
                        input.selection = TextSelection.collapsed(offset: s.length);
                        setState(() => q = s);
                      }),
                  ]),
                  const SizedBox(height: 14),
                  const Muted('Find a page or setting, a customer, a testimonial, a request, a group, a business in Media, or an answer in Help.', size: 13),
                ] else if (nothing)
                  EmptyState(Icons.search_off_rounded, 'No results for "$q"', 'Check the spelling, or try a shorter word such as "invoice" or "reminder".')
                else ...[
                  _section('Pages and settings', [
                    for (var i = 0; i < pages.take(6).length; i++)
                      _row(Icon(pages[i].$1.icon, color: C.primary), pages[i].$1.title, pages[i].$1.where, () => _go(() {
                            Navigator.of(context).pop();
                            pages[i].$1.open(shell.context, shell);
                          }), last: i == pages.take(6).length - 1),
                  ]),
                  _section('Customers', [
                    for (var i = 0; i < people.length; i++)
                      _row(Avatar(people[i].name, size: 36), people[i].name, '${people[i].job} · ${people[i].phone.isEmpty ? people[i].status : people[i].phone}',
                          () => _go(() => _push(context, ContactDetailScreen(customer: people[i]))), last: i == people.length - 1),
                  ]),
                  _section('Testimonials', [
                    for (var i = 0; i < reviews.length; i++)
                      _row(Avatar(reviews[i].name, size: 36), reviews[i].name, '${reviews[i].job} · ${reviews[i].status}', () => _go(() => _push(context, VideoDetailScreen(video: reviews[i]))), last: i == reviews.length - 1),
                  ]),
                  _section('Requests', [
                    for (var i = 0; i < requests.length; i++)
                      _row(Avatar(requests[i].name, size: 36), requests[i].name, requests[i].service, () => _go(() => _push(context, LeadThreadScreen(lead: requests[i]))), last: i == requests.length - 1),
                  ]),
                  _section('Groups', [
                    for (var i = 0; i < grp.length; i++)
                      _row(Icon(Icons.groups_rounded, color: C.primary), grp[i].name, '${grp[i].memberIds.length} people · ${grp[i].purposeLabel}', () => _go(() {
                            Navigator.of(context).pop();
                            _tab(shell, 16);
                          }), last: i == grp.length - 1),
                  ]),
                  _section('In Media', [
                    for (var i = 0; i < biz.length; i++)
                      _row(Avatar(biz[i].business, size: 36), biz[i].business, '${biz[i].handle} · ${biz[i].category}', () => _go(() => openProfile(context, biz[i].businessId)), last: i == biz.length - 1),
                  ]),
                  _section('Help', [
                    for (var i = 0; i < help.length; i++)
                      _row(Icon(Icons.help_outline_rounded, color: C.primary), help[i].$1, help[i].$2, () => _go(() => _push(context, const HelpScreen())), last: i == help.length - 1),
                  ]),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
