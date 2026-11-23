import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'help.dart';
import '../theme_controller.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  static String _themeLabel(AppThemeMode m) => switch (m) {
        AppThemeMode.system => 'Automatic (follows your phone)',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
      };

  void _pickTheme(BuildContext context) {
    final ctl = ThemeController.instance;
    showSheet(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Appearance'),
        const SizedBox(height: 4),
        const Muted('Choose how ViewRec looks. Automatic switches with your phone.', size: 13),
        const SizedBox(height: 12),
        for (final m in AppThemeMode.values)
          InkWell(
            onTap: () {
              ctl.setMode(m);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(
                  switch (m) { AppThemeMode.system => Icons.phone_android_rounded, AppThemeMode.light => Icons.light_mode_rounded, AppThemeMode.dark => Icons.dark_mode_rounded },
                  color: C.primary,
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(_themeLabel(m), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                if (ctl.mode == m) Icon(Icons.check_circle_rounded, color: C.primary, size: 20),
              ]),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        GestureDetector(
          onTap: () => _go(context, const BusinessProfileScreen()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8468FF), Color(0xFF4B2FCB)]),
              boxShadow: [BoxShadow(color: C.primary.withValues(alpha: C.dark ? 0.32 : 0.28), blurRadius: 30, offset: const Offset(0, 14))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                child: const Avatar('Hartley Roofing', size: 60),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hartley Roofing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Colors.white, letterSpacing: -0.4)),
                  const SizedBox(height: 3),
                  Text('Home & Trades · demo@viewrec.com', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                    child: const Text('Pro trial · day 4 of 15', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 26),
            ]),
          ),
        ),
        const SectionHeader('Business'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            Tile(icon: Icons.storefront_rounded, title: 'Business profile', subtitle: 'Name, category, contact details', onTap: () => _go(context, const BusinessProfileScreen())),
            Tile(icon: Icons.palette_rounded, title: 'Branding & invitations', subtitle: 'Logo, colours, message wording', onTap: () => _go(context, const BrandingScreen())),
            Tile(icon: Icons.group_rounded, title: 'Team members', subtitle: '2 people', onTap: () => _go(context, const TeamScreen())),
            Tile(icon: Icons.block_rounded, title: 'Opt-out list', subtitle: '4 people will never be contacted again', divider: false, onTap: () => _go(context, const OptOutsScreen())),
          ]),
        ),
        const SectionHeader('Preferences'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            Tile(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'Push, email and text alerts', onTap: () => _go(context, const NotificationPrefsScreen())),
            Tile(icon: Icons.contrast_rounded, title: 'Appearance', subtitle: _themeLabel(ThemeController.instance.mode), onTap: () => _pickTheme(context)),
            Tile(icon: Icons.language_rounded, title: 'Language & region', subtitle: 'English (UK) · Europe/London', divider: false, onTap: () {}),
          ]),
        ),
        const SectionHeader('Security & privacy'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            Tile(icon: Icons.lock_outline_rounded, title: 'Password & sign-in', onTap: () {}),
            Tile(icon: Icons.privacy_tip_rounded, title: 'Data & privacy', subtitle: 'Export or delete your data', divider: false, onTap: () {}),
          ]),
        ),
        const SectionHeader('Support'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            Tile(icon: Icons.help_outline_rounded, title: 'Help & FAQs', onTap: () => _go(context, const HelpScreen())),
            Tile(icon: Icons.info_outline_rounded, title: 'About ViewRec', subtitle: 'Version 1.0.0', divider: false, onTap: () {}),
          ]),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst),
            child: const Text('Sign out', style: TextStyle(color: C.rec, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 80),
      ]);
}

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader('Business profile')),
            Expanded(
              child: AsyncView<BusinessProfile>(
                load: repo.profile,
                skeletonCards: 3,
                builder: (context, p, refresh) => _ProfileForm(profile: p),
              ),
            ),
          ]),
        ),
      );
}

class _ProfileForm extends StatefulWidget {
  final BusinessProfile profile;
  const _ProfileForm({required this.profile});
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final name = TextEditingController(text: widget.profile.name);
  late final category = TextEditingController(text: widget.profile.category);
  late final phone = TextEditingController(text: widget.profile.phone);
  late final email = TextEditingController(text: widget.profile.email);
  late final website = TextEditingController(text: widget.profile.website);
  late final area = TextEditingController(text: widget.profile.area);
  late final about = TextEditingController(text: widget.profile.about);
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final c in [name, category, phone, email, website, area, about]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (n.isEmpty) {
      setState(() => error = 'Business name is required');
      return;
    }
    final mail = email.text.trim();
    if (mail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      setState(() => error = 'Enter a valid email address');
      return;
    }
    setState(() {
      error = null;
      saving = true;
    });
    try {
      await repo.saveProfile(BusinessProfile(
        name: n,
        category: category.text.trim(),
        phone: phone.text.trim(),
        email: mail,
        website: website.text.trim(),
        area: area.text.trim(),
        about: about.text.trim(),
      ));
      if (mounted) {
        Navigator.pop(context);
        showMsg(context, 'Profile saved');
      }
    } catch (_) {
      if (mounted) setState(() => error = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Center(child: Avatar(name.text.isEmpty ? 'HR' : name.text, size: 80)),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: () {}, child: const Text('Change logo'))),
        const SizedBox(height: 8),
        Field('Business name', controller: name, onChanged: (_) => setState(() {})),
        Field('Category', controller: category),
        Field('Phone', controller: phone, keyboard: TextInputType.phone),
        Field('Email', controller: email, keyboard: TextInputType.emailAddress),
        Field('Website', controller: website, keyboard: TextInputType.url),
        Field('Service area', controller: area),
        Field('About', controller: about, lines: 3),
        if (error != null)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
        AppButton(saving ? 'Saving…' : 'Save changes', onTap: saving ? null : _save),
      ]);
}

class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});
  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  int color = 0;
  bool logoOnInvites = true, thankYou = true;
  final msg = TextEditingController(text: 'Hi {first_name}, thanks for choosing Hartley Roofing. Would you record a quick 2-minute video about how it went? {link}');
  List<Color> get palette => [C.primary, C.green, C.blue, C.amber, C.rec];

  @override
  void dispose() {
    msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubPage('Branding & invitations', children: [
        InfoBanner('Your logo on invitations and thank-you pages is part of the Pro plan.', icon: Icons.workspace_premium_rounded, color: C.amber),
        const SizedBox(height: 16),
        const H2('Accent colour'),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < palette.length; i++)
            GestureDetector(
              onTap: () => setState(() => color = i),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: palette[i], shape: BoxShape.circle, border: Border.all(color: color == i ? Colors.white : Colors.transparent, width: 3)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        AppCard(
          child: Column(children: [
            SwitchTile('Logo on invitations', logoOnInvites, (v) => setState(() => logoOnInvites = v)),
            Divider(color: C.border),
            SwitchTile('Branded thank-you page', thankYou, (v) => setState(() => thankYou = v)),
          ]),
        ),
        const SizedBox(height: 16),
        const H2('Invitation message'),
        const SizedBox(height: 10),
        Field('Text / email wording', controller: msg, lines: 5),
        const Muted('Use {first_name} and {link}. We write a good version for you if you leave it as it is.', size: 12.5),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PREVIEW', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette[color].withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: Text(msg.text.replaceAll('{first_name}', 'Sarah').replaceAll('{link}', 'viewrec.com/r/demo'), style: const TextStyle(height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        AppButton('Save branding', onTap: () {
          Navigator.pop(context);
          showMsg(context, 'Branding saved');
        }),
      ]);
}

class OptOutsScreen extends StatefulWidget {
  const OptOutsScreen({super.key});
  @override
  State<OptOutsScreen> createState() => _OptOutsScreenState();
}

class _OptOutsScreenState extends State<OptOutsScreen> {
  final people = const [
    ('Marcus Webb', 'Asked to stop · 3 weeks ago', 'Text reply STOP'),
    ('Eleanor Pryce', 'Asked to stop · 2 months ago', 'Via video link'),
    ('R. Dawson', 'Asked to stop · 4 months ago', 'Email unsubscribe'),
    ('+44 7700 900456', 'Asked to stop · 5 months ago', 'Text reply STOP'),
  ];
  @override
  Widget build(BuildContext context) => SubPage('Opt-out list', children: [
        const InfoBanner('An opt-out is final. Someone who says stop is never contacted again - by you or by anyone else we work with.', icon: Icons.block_rounded, color: C.rec),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < people.length; i++)
              Tile(
                icon: Icons.person_off_rounded,
                iconColor: C.muted,
                title: people[i].$1,
                subtitle: '${people[i].$2} · ${people[i].$3}',
                divider: i < people.length - 1,
              ),
          ]),
        ),
        const SizedBox(height: 14),
        AppButton('Add a number or email', icon: Icons.add_rounded, style: BtnStyle.ghost, onTap: () => showSheet(
              context,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const H2('Add to opt-out list'),
                const SizedBox(height: 6),
                const Muted('Use this if someone tells you they never want to be contacted. It cannot be undone.', size: 13),
                const SizedBox(height: 14),
                const Field('Mobile number or email'),
                AppButton('Add to list', style: BtnStyle.danger, onTap: () {
                  Navigator.pop(context);
                  showMsg(context, 'Added');
                }),
              ]),
            )),
      ]);
}

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context) => SubPage('Team members', children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            const Tile(icon: Icons.person_outline_rounded, title: 'demo (you)', subtitle: 'demo@viewrec.com · Owner'),
            Tile(icon: Icons.person_outline_rounded, title: 'Jordan Hartley', subtitle: 'jordan@hartleyroofing.example · Editor', divider: false, onTap: () {}),
          ]),
        ),
        const SizedBox(height: 14),
        AppButton('Invite a teammate', icon: Icons.person_add_alt_rounded, onTap: () => showMsg(context, 'Invitation sent')),
      ]);
}

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool newVideo = true, newLead = true, approvals = true, weekly = false, posts = true;
  @override
  Widget build(BuildContext context) => SubPage('Notifications', children: [
        AppCard(
          child: Column(children: [
            SwitchTile('New video testimonial', newVideo, (v) => setState(() => newVideo = v)),
            Divider(color: C.border),
            SwitchTile('New lead or request', newLead, (v) => setState(() => newLead = v)),
            Divider(color: C.border),
            SwitchTile('Waiting for your approval', approvals, (v) => setState(() => approvals = v)),
            Divider(color: C.border),
            SwitchTile('Post published or failed', posts, (v) => setState(() => posts = v)),
            Divider(color: C.border),
            SwitchTile('Weekly summary email', weekly, (v) => setState(() => weekly = v)),
          ]),
        ),
      ]);
}
