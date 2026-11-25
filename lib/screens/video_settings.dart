import 'package:flutter/material.dart';
import '../async_view.dart';
import '../entitlement.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Video settings: subtitles on every video (Pro and up) and the ViewRec watermark (removable on Pro Plus and above).
class VideoSettingsScreen extends StatelessWidget {
  const VideoSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<(VideoSettings, Entitlement)>(
        load: () async => (await webRepo.videoSettings(), await loadEntitlement()),
        skeletonCards: 2,
        builder: (context, d, refresh) => _Body(settings: d.$1, ent: d.$2),
      );
}

class _Body extends StatefulWidget {
  final VideoSettings settings;
  final Entitlement ent;
  const _Body({required this.settings, required this.ent});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final s = widget.settings;

  Future<void> _save() async {
    try {
      await webRepo.saveVideoSettings(s);
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't save. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.ent;
    return AppPage(reveal: false, children: [
      const Muted('How your published videos look to the people who watch them.').reveal(context, 0),
      const SizedBox(height: 14),
      AppCard(
        child: Column(children: [
          SwitchTile(
            'Subtitles',
            e.allows('subtitles') ? s.subtitles : false,
            (v) {
              if (!e.allows('subtitles')) {
                showUpgrade(context, e, 'subtitles', 'Subtitles');
                return;
              }
              setState(() => s.subtitles = v);
              _save();
            },
            subtitle: e.allows('subtitles') ? 'Words appear on screen. Viewers can switch them off.' : 'Pro feature. Subtitles are made from the audio of each video.',
          ),
          Divider(color: C.border, height: 24),
          SwitchTile(
            'Show the ViewRec watermark',
            s.watermark,
            (v) {
              if (!v && !e.allows('remove_watermark')) {
                showUpgrade(context, e, 'remove_watermark', 'Removing the watermark');
                return;
              }
              setState(() => s.watermark = v);
              _save();
            },
            subtitle: e.allows('remove_watermark') ? 'You can switch it off on your plan.' : 'Removing it needs Pro Plus or Managed.',
          ),
        ]),
      ).reveal(context, 1),
      if (!e.allows('subtitles') || !e.allows('remove_watermark')) ...[
        const SizedBox(height: 14),
        const InfoBanner('Some settings are locked on your plan. Change your plan under Plan & billing to unlock them.', icon: Icons.lock_rounded).reveal(context, 2),
      ],
      const SizedBox(height: 80),
    ]);
  }
}
