import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import '../repo.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class VideoDetailScreen extends StatefulWidget {
  final Video video;
  const VideoDetailScreen({super.key, required this.video});
  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late bool approved = widget.video.status != 'pending';
  late final Map<String, bool> on = {
    for (final p in platforms) p.id: widget.video.platforms.contains(p.name.split(' ').first),
  };

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Scaffold(
      body: AppPage(children: [
        const BackHeader('Testimonial', trailing: Icon(Icons.ios_share_rounded, size: 22)),
        Hero(tag: 'video_${v.id}', child: VideoThumb(hue: v.hue, duration: v.duration, height: 240)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 2),
              Muted(v.job, size: 13),
            ]),
          ),
          StatusBadge(approved && v.status == 'pending' ? 'approved' : v.status),
        ]),
        if (v.quote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('“${v.quote}”', style: const TextStyle(fontSize: 15, height: 1.45)),
        ],
        const SizedBox(height: 16),
        AppCard(
          child: Row(children: [
            Icon(Icons.verified_user_rounded, size: 26, color: C.green),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Verified capture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 2),
                Muted('Recorded in one session, in the app, with permission given on the page.', size: 13),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: StatCard(icon: Icons.visibility_rounded, label: 'Views', value: '${v.views}')),
          const SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.share_rounded, label: 'Shared to', value: '${v.platforms.length}')),
        ]),
        const SizedBox(height: 16),
        if (!approved) ...[
          AppButton('Approve video', icon: Icons.check_rounded, onTap: () {
            setState(() => approved = true);
            repo.updateVideo(v.id, status: 'approved').catchError((_) {});
          }),
          const SizedBox(height: 8),
          AppButton('Request a re-record', style: BtnStyle.ghost, onTap: () => showMsg(context, 'Re-record request sent')),
        ] else ...[
          const SizedBox(height: 8),
          const H2('Publish to'),
          const SizedBox(height: 4),
          const Muted('You choose each one. Nothing goes out on its own.'),
          const SizedBox(height: 8),
          for (final p in platforms)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: C.surface2, child: Icon(p.icon, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15))),
                LiquidSwitch(value: on[p.id]!, onChanged: (x) => setState(() => on[p.id] = x)),
              ]),
            ),
          const SizedBox(height: 16),
          AppButton('Publish selected', icon: Icons.rocket_launch_rounded, onTap: () async {
            final chosen = platforms.where((p) => on[p.id]!).map((p) => p.name).toList();
            try {
              await repo.updateVideo(v.id, status: 'published', platforms: chosen);
              if (context.mounted) Navigator.of(context).pop();
            } catch (_) {
              if (context.mounted) showMsg(context, "Couldn't publish - server not reachable.");
            }
          }),
        ],
      ]),
    );
  }
}
