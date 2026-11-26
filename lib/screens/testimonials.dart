import 'package:flutter/material.dart';
import '../icons.dart';
import '../async_view.dart';
import '../data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'video_detail.dart';

class TestimonialsScreen extends StatefulWidget {
  const TestimonialsScreen({super.key});
  @override
  State<TestimonialsScreen> createState() => _TestimonialsScreenState();
}

class _TestimonialsScreenState extends State<TestimonialsScreen> {
  static const filters = ['All', 'Waiting', 'Approved', 'Published', 'Video', 'Written'];
  int f = 0;
  bool dragging = false;

  bool _match(Video v) => switch (f) {
        1 => v.status == 'pending',
        2 => v.status == 'approved',
        3 => v.status == 'published',
        4 => !v.written,
        5 => v.written,
        _ => true,
      };

  @override
  Widget build(BuildContext context) => AsyncView<List<Video>>(
        load: repo.videos,
        builder: (context, items, refresh) {
          final shown = items.where(_match).toList();
          final avg = items.isEmpty ? 0.0 : items.map((v) => v.rating).reduce((a, b) => a + b) / items.length;
          final waiting = items.where((v) => v.status == 'pending').length;
          return Stack(children: [
            RefreshIndicator(
            color: C.primary,
            onRefresh: refresh,
            child: AppPage(reveal: false, children: [
              _summary(context, items.length, avg, waiting).reveal(context, 0),
              const SizedBox(height: 16),
              Pills(filters, f, (i) => setState(() => f = i)).reveal(context, 1),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: kMed,
                switchInCurve: kCurve,
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c)),
                child: Column(
                  key: ValueKey(f),
                  children: [
                    if (shown.isEmpty) const EmptyState(PIconsRegular.quotes, 'Nothing here yet', 'Testimonials appear here when customers reply.'),
                    for (var i = 0; i < shown.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _draggable(
                          shown[i],
                          _TestimonialCard(
                            video: shown[i],
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoDetailScreen(video: shown[i])));
                              if (mounted) refresh();
                            },
                          ),
                        ).reveal(context, 2 + i, 0.1),
                      ),
                  ],
                ),
              ),
            ]),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DropZoneBar<Video>(
                show: dragging,
                zones: [DropZone('approved', 'Approve', C.green, Icons.check_circle_rounded)],
                canDrop: (v, id) => v.status == 'pending',
                onDrop: (v, id) async {
                  setState(() => v.status = 'approved');
                  showSuccess(context, '${v.name} approved');
                  try {
                    await repo.updateVideo(v.id, status: 'approved');
                  } catch (_) {
                    if (mounted) {
                      setState(() => v.status = 'pending');
                      showMsg(context, "Couldn't approve. Try again.");
                    }
                  }
                },
              ),
            ),
          ]);
        },
      );

  /// Only waiting testimonials can be dragged, to be approved.
  Widget _draggable(Video v, Widget card) {
    if (v.status != 'pending') return card;
    return DragCard<Video>(
      data: v,
      onStart: () => setState(() => dragging = true),
      onEnd: () => setState(() => dragging = false),
      child: card,
    );
  }

  Widget _summary(BuildContext context, int count, double avg, int waiting) => AppCard(
        child: Row(children: [
          AnimatedRing(
            progress: avg / 5,
            size: 74,
            stroke: 7,
            color: C.amber,
            track: C.surface2,
            child: CountUp(avg, decimals: 1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CountUp(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1)),
                const SizedBox(width: 8),
                Text('testimonials', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.muted)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Stars(avg.round()),
                const SizedBox(width: 8),
                if (waiting > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: C.amber.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                    child: Text('$waiting waiting', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.amber)),
                  ),
              ]),
            ]),
          ),
        ]),
      );
}

class _TestimonialCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  const _TestimonialCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = video;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rLg + 4), border: Border.all(color: C.border), boxShadow: C.shadow),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!v.written) _media(v) else _quoteHeader(v),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (v.quote.isNotEmpty)
                Text('“${v.quote}”', maxLines: v.written ? 4 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(children: [
                Avatar(v.name, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                Icon(PIconsRegular.eye, size: 15, color: C.muted),
                const SizedBox(width: 4),
                Text('${v.views}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _media(Video v) => AspectRatio(
        aspectRatio: 16 / 10,
        child: Hero(
          tag: 'video_${v.id}',
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [v.hue, Color.lerp(v.hue, Colors.black, 0.6)!])),
            child: Stack(children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
                  child: const Icon(PIconsFill.play, color: Colors.white, size: 26),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)])),
                  child: Row(children: [
                    for (var i = 0; i < 5; i++) Icon(i < v.rating ? PIconsFill.star : PIconsRegular.star, size: 13, color: const Color(0xFFFFC21A)),
                    const Spacer(),
                    Text(v.job, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
              if (v.duration.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                    child: Text(v.duration, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              Positioned(top: 12, right: 12, child: StatusBadge(v.status)),
            ]),
          ),
        ),
      );

  Widget _quoteHeader(Video v) => Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [v.hue.withValues(alpha: 0.9), Color.lerp(v.hue, Colors.black, 0.5)!])),
        child: Row(children: [
          const Icon(PIconsFill.quotes, color: Colors.white54, size: 34),
          const Spacer(),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 5; i++) Icon(i < v.rating ? PIconsFill.star : PIconsRegular.star, size: 13, color: const Color(0xFFFFC21A))]),
            const SizedBox(height: 6),
            StatusBadge(v.status),
          ]),
        ]),
      );
}
