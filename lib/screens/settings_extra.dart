import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'security.dart';

/// Small saved-on-this-phone preferences for the Settings screens.
class AppPrefs {
  static final language = ValueNotifier<String>('English (UK)');
  static final region = ValueNotifier<String>('Europe/London');
  static final dateFormat = ValueNotifier<String>('DD/MM/YYYY');
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      language.value = p.getString('pref_language') ?? language.value;
      region.value = p.getString('pref_region') ?? region.value;
      dateFormat.value = p.getString('pref_date') ?? dateFormat.value;
    } catch (_) {}
  }

  static Future<void> save(String key, String value) async {
    try {
      (await SharedPreferences.getInstance()).setString(key, value);
    } catch (_) {}
  }

  static Future<bool> getBool(String key, bool fallback) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> setBool(String key, bool v) async {
    try {
      (await SharedPreferences.getInstance()).setBool(key, v);
    } catch (_) {}
  }

  static Future<String?> getString(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------- language and region
class LanguageRegionScreen extends StatefulWidget {
  const LanguageRegionScreen({super.key});
  @override
  State<LanguageRegionScreen> createState() => _LanguageRegionScreenState();
}

class _LanguageRegionScreenState extends State<LanguageRegionScreen> {
  static const languages = ['English (UK)', 'English (US)', 'Español', 'Français', 'Deutsch', 'Português', 'Italiano', 'العربية', 'اردو', 'हिन्दी'];
  static const regions = [
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Asia/Dubai',
    'Asia/Karachi',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Australia/Sydney',
  ];
  static const formats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];

  Widget _group(String title, List<String> options, ValueNotifier<String> value, String key) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ValueListenableBuilder<String>(
            valueListenable: value,
            builder: (_, cur, __) => Column(children: [
              for (var i = 0; i < options.length; i++)
                Pressable(
                  scale: 0.99,
                  onTap: () {
                    value.value = options[i];
                    AppPrefs.save(key, options[i]);
                    showMsg(context, 'Saved: ${options[i]}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                    decoration: BoxDecoration(border: i < options.length - 1 ? Border(bottom: BorderSide(color: C.border)) : null),
                    child: Row(children: [
                      Expanded(child: Text(options[i], style: TextStyle(fontSize: 15, fontWeight: cur == options[i] ? FontWeight.w800 : FontWeight.w600))),
                      if (cur == options[i]) Icon(Icons.check_circle_rounded, color: C.primary, size: 22),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) => SubPage('Language & region', children: [
        InfoBanner('ViewRec screens are in English for now. Your choices are saved and kept ready for when more languages are added.', icon: Icons.language_rounded, color: C.blue),
        _group('Language', languages, AppPrefs.language, 'pref_language'),
        _group('Time zone', regions, AppPrefs.region, 'pref_region'),
        _group('Date format', formats, AppPrefs.dateFormat, 'pref_date'),
        const SizedBox(height: 60),
      ]);
}

// ---------------------------------------------------------------- password and sign-in
class PasswordSignInScreen extends StatefulWidget {
  const PasswordSignInScreen({super.key});
  @override
  State<PasswordSignInScreen> createState() => _PasswordSignInScreenState();
}

class _PasswordSignInScreenState extends State<PasswordSignInScreen> {
  final current = TextEditingController(), next = TextEditingController(), again = TextEditingController();
  bool saving = false, show = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (current.text.isEmpty) return setState(() => error = 'Enter your current password');
    if (next.text.length < 8) return setState(() => error = 'The new password needs at least 8 characters');
    if (next.text != again.text) return setState(() => error = 'The two new passwords do not match');
    if (next.text == current.text) return setState(() => error = 'Choose a password you have not used just now');
    setState(() {
      error = null;
      saving = true;
    });
    try {
      await webRepo.changePassword(current: current.text, next: next.text);
      if (!mounted) return;
      current.clear();
      next.clear();
      again.clear();
      showSuccess(context, 'Password changed');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _pw(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: !show,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: C.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: C.primary, width: 1.6)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SubPage('Password & sign-in', children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Change your password'),
            const SizedBox(height: 14),
            _pw('Current password', current),
            _pw('New password', next),
            _pw('Repeat the new password', again),
            Row(children: [
              Switch(value: show, activeThumbColor: C.primary, onChanged: (v) => setState(() => show = v)),
              const SizedBox(width: 6),
              const Text('Show passwords', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6, bottom: 4), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
            const SizedBox(height: 8),
            AppButton(saving ? 'Saving…' : 'Change password', loading: saving, onTap: saving ? null : _save),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Tile(
            icon: Icons.shield_rounded,
            title: 'Two-step sign-in and devices',
            subtitle: 'Turn on the email code and see where you are signed in',
            divider: false,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubPageShell(title: 'Security', child: SecurityScreen()))),
          ),
        ),
        const SizedBox(height: 60),
      ]);
}

/// A full page around a screen that normally lives inside the main tabs.
class SubPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  const SubPageShell({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader(title)),
              Expanded(child: child),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- data and privacy
class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});
  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  bool exporting = false;

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      await webRepo.requestDataExport();
      if (mounted) showSuccess(context, 'Export requested. We will email you a download link.');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't request the export. Try again.");
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _delete() async {
    final word = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Delete your account?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All your videos, customers and settings will be removed after 30 days. This cannot be undone. Type DELETE to confirm.', style: TextStyle(color: C.muted, height: 1.4)),
            const SizedBox(height: 12),
            TextField(controller: word, onChanged: (_) => set(() {}), textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'DELETE')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep my account', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
            TextButton(
              onPressed: word.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: Text('Delete', style: TextStyle(color: word.text.trim() == 'DELETE' ? C.rec : C.muted, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await webRepo.requestAccountDeletion();
      if (mounted) showMsg(context, 'Deletion requested. Your account closes in 30 days. Email support to cancel.');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't send the request. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) => SubPage('Data & privacy', children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Download your data'),
            const SizedBox(height: 6),
            const Muted('Get a copy of your customers, videos and messages. We email you a link when it is ready.', size: 13.5),
            const SizedBox(height: 14),
            AppButton('Request my data', icon: Icons.download_rounded, loading: exporting, onTap: exporting ? null : _export),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          borderColor: C.rec.withValues(alpha: 0.4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Delete your account'),
            const SizedBox(height: 6),
            const Muted('Removes your account, videos and customers. You have 30 days to change your mind.', size: 13.5),
            const SizedBox(height: 14),
            AppButton('Delete my account', icon: Icons.delete_forever_rounded, style: BtnStyle.danger, onTap: _delete),
          ]),
        ),
        const SizedBox(height: 60),
      ]);
}

// ---------------------------------------------------------------- about
void showAbout(BuildContext context) => showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, children: [
        const BrandMark(size: 64),
        const SizedBox(height: 10),
        const Text('ViewRec', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        const SizedBox(height: 4),
        const Muted('Version 1.0.0', size: 13),
        const SizedBox(height: 14),
        const Muted('Video testimonials you can stand behind. Built by Systematic IT Solutions.', size: 13.5, align: TextAlign.center),
        const SizedBox(height: 6),
        const Muted('© 2026 ViewRec', size: 12, align: TextAlign.center),
        const SizedBox(height: 10),
      ]),
    );
