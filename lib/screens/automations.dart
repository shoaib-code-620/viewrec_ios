import 'package:flutter/material.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

class AutomationsScreen extends StatelessWidget {
  const AutomationsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<AutomationSettings>(
        load: repo.automations,
        skeletonCards: 3,
        builder: (context, s, refresh) => _AutomationsBody(settings: s),
      );
}

class _AutomationsBody extends StatefulWidget {
  final AutomationSettings settings;
  const _AutomationsBody({required this.settings});
  @override
  State<_AutomationsBody> createState() => _AutomationsBodyState();
}

class _AutomationsBodyState extends State<_AutomationsBody> {
  late final AutomationSettings s = widget.settings;
  bool saving = false;
  bool dirty = false;

  static const channels = [('sms_email', 'SMS + Email'), ('sms', 'SMS only'), ('email', 'Email only'), ('whatsapp', 'WhatsApp')];

  void _change(VoidCallback f) => setState(() {
        f();
        dirty = true;
      });

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await repo.saveAutomations(s);
      if (mounted) {
        setState(() => dirty = false);
        showMsg(context, 'Automations saved');
      }
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        const Muted('Let ViewRec do the asking at the right moment, so you never forget.'),
        const SizedBox(height: 14),
        const InfoBanner('Invitations only go out between 8am and 8pm where your business is, and never to the same person twice in six months.'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(children: [
            SwitchTile('Ask after every completed job', s.requestAfterJob, (v) => _change(() => s.requestAfterJob = v), subtitle: 'Send an invitation when a job is marked complete'),
            Divider(color: C.border),
            SwitchTile('Auto-invite approved customers', s.autoInvite, (v) => _change(() => s.autoInvite = v), subtitle: 'Skip the manual send step'),
            Divider(color: C.border),
            SwitchTile('Thank-you message', s.thankYou, (v) => _change(() => s.thankYou = v), subtitle: 'Sent as soon as a video arrives'),
          ]),
        ),
        const SectionHeader('Reminders'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchTile('Send reminders', s.reminders, (v) => _change(() => s.reminders = v)),
            if (s.reminders) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Number of reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${s.reminderCount}', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
              ]),
              Slider(value: s.reminderCount.toDouble(), min: 1, max: 5, divisions: 4, activeColor: C.primary, onChanged: (v) => _change(() => s.reminderCount = v.round())),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Days between reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${s.gapDays}', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
              ]),
              Slider(value: s.gapDays.toDouble(), min: 1, max: 10, divisions: 9, activeColor: C.primary, onChanged: (v) => _change(() => s.gapDays = v.round())),
              const Muted('Standard plans send one reminder after 3 days. Pro lets you choose up to 5.', size: 12.5),
            ],
          ]),
        ),
        const SectionHeader('How we reach them'),
        AppCard(
          child: Column(children: [
            for (final c in channels)
              InkWell(
                onTap: () => _change(() => s.channel = c.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Icon(s.channel == c.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: s.channel == c.$1 ? C.primary : C.muted, size: 20),
                    const SizedBox(width: 12),
                    Text(c.$2, style: const TextStyle(fontSize: 15)),
                  ]),
                ),
              ),
          ]),
        ),
        const SectionHeader('Publishing'),
        AppCard(
          child: Column(children: [
            SwitchTile('Auto-publish approved videos', s.autoPublish, (v) => _change(() => s.autoPublish = v), subtitle: 'Off by default - you choose each one'),
            Divider(color: C.border),
            SwitchTile('Polite hours only', s.politeHours, (v) => _change(() => s.politeHours = v), subtitle: '8am to 8pm in your timezone'),
          ]),
        ),
        const SizedBox(height: 20),
        AppButton(saving ? 'Saving…' : 'Save automations', icon: saving ? null : Icons.check_rounded, onTap: (saving || !dirty) ? null : _save),
        const SizedBox(height: 80),
      ]);
}
