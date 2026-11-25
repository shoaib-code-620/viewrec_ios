import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../icons.dart';
import '../async_view.dart';
import '../data.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entitlement.dart';
import '../media_data.dart';
import 'insights.dart';
import 'media.dart' show StoriesRow;
import 'invite_composer.dart';
import 'record.dart';
import 'video_detail.dart';

class OverviewScreen extends StatelessWidget {
  final ShellState shell;
  const OverviewScreen({super.key, required this.shell});

  Future<(OverviewStats, List<Video>, List<StoryGroup>)> _load() async {
    final stats = await repo.overview();
    final videos = await repo.videos();
    // Stories are a bonus on Home: if they fail to load, the rest of the page still shows.
    final stories = await repo.stories().catchError((_) => <StoryGroup>[]);
    return (stats, videos, stories);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: mediaRevision,
        builder: (context, rev, _) => AsyncView<(OverviewStats, List<Video>, List<StoryGroup>)>(
          key: ValueKey(rev),
          load: _load,
          builder: (context, data, refresh) => RefreshIndicator(
            color: C.primary,
            onRefresh: refresh,
            child: _body(context, data.$1, data.$2, data.$3),
          ),
        ),
      );

  Widget _body(BuildContext context, OverviewStats s, List<Video> videos, List<StoryGroup> stories) {
    var n = 0;
    return AppPage(reveal: false, children: [
      if (stories.isNotEmpty) ...[
        StoriesRow(stories: stories),
        const SizedBox(height: 6),
      ],
      EntitlementBanner(onBilling: () => shell.goTo(9)),
      reduceMotion(context)
          ? _hero(context, s).reveal(context, n++)
          : _hero(context, s).reveal(context, n++).animate().shimmer(delay: 1100.ms, duration: 1500.ms, color: Colors.white.withValues(alpha: 0.16), angle: 0.6),
      const SizedBox(height: 18),
      _quickActions(context).reveal(context, n++),
      const SizedBox(height: 18),
      AppButton('Send custom invitation', icon: PIconsBold.paperPlaneTilt, onTap: () => shell.push(const InviteComposerScreen())).reveal(context, n++),
      if (videos.isNotEmpty) ...[
        SectionHeader('Latest testimonials', action: 'See all', onAction: () => shell.goTo(1)).reveal(context, n++),
        SizedBox(
          height: 226,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _StoryCard(video: videos[i], onTap: () => shell.push(VideoDetailScreen(video: videos[i]))).reveal(context, n + i, 0.12),
          ),
        ),
      ],
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: _metric(context, PIconsFill.clock, 'Waiting', s.waiting.toDouble(), C.amber, () => shell.goTo(1))),
        const SizedBox(width: 10),
        Expanded(child: _metric(context, PIconsFill.paperPlaneTilt, 'Invites sent', s.invitesSent.toDouble(), C.blue, () => shell.goTo(4))),
        const SizedBox(width: 10),
        Expanded(child: _metric(context, PIconsFill.users, 'To ask', s.customers.toDouble(), C.green, () => shell.goTo(3))),
      ]).reveal(context, n++),
      _checklist(context, s).reveal(context, n++),
      const SizedBox(height: 14),
      AppCard(
        onTap: () => shell.push(const InsightsScreen()),
        child: Row(children: [
          GlossIcon(PIconsFill.chartLineUp, C.primary, size: 48),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Insights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 2),
              Muted('Views, plays and how many customers reply', size: 12.5),
            ]),
          ),
          Icon(PIconsBold.caretRight, color: C.muted, size: 16),
        ]),
      ).reveal(context, n++),
    ]);
  }

  // ---------- hero ----------
  Widget _hero(BuildContext context, OverviewStats s) => ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlueDeep, stops: [0, 0.55, 1]),
            boxShadow: [BoxShadow(color: C.primary.withValues(alpha: C.dark ? 0.35 : 0.3), blurRadius: 36, offset: const Offset(0, 16))],
          ),
          child: Stack(children: [
            const Positioned.fill(child: PlayPattern()),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PIconsBold.videoCamera, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Flexible(child: Text('Videos', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white))),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF1FC9A4).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PIconsBold.trendUp, size: 13, color: Color(0xFF5BE8C6)),
                      SizedBox(width: 4),
                      Text('+12% this week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5BE8C6))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CountUp(s.testimonials, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w800, letterSpacing: -3, height: 1, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('testimonials collected', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                    ]),
                  ),
                  AnimatedRing(
                    progress: s.averageRating / 5,
                    size: 78,
                    stroke: 8,
                    color: Colors.white,
                    track: Colors.white.withValues(alpha: 0.2),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CountUp(s.averageRating, decimals: 1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05)),
                      Icon(PIconsFill.star, size: 11, color: Colors.white.withValues(alpha: 0.9)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Sparkline(values: [2, 3, 3, 5, 4, 6, 5, s.testimonials + 1], color: Colors.white, height: 58),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(PIconsRegular.link, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.videoLink, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95)))),
                    Pressable(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: s.videoLink));
                        showMsg(context, 'Link copied');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                        child: const Text('Copy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0847A0))),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );

  // ---------- quick actions ----------
  Widget _quickActions(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (PIconsFill.chatText, 'SMS', const Color(0xFF3E94F5), () => showVideoLinkSheet(context)),
      (PIconsFill.envelopeSimple, 'Email', const Color(0xFFFFC21A), () => showVideoLinkSheet(context)),
      (PIconsFill.whatsappLogo, 'WhatsApp', const Color(0xFF1FC9A4), () => showVideoLinkSheet(context)),
      (PIconsFill.qrCode, 'QR', const Color(0xFF1FC9A4), () => shell.goTo(6)),
      (PIconsFill.playCircle, 'Preview', C.rec, () => shell.push(const RecordScreen())),
    ];
    return _QuickActions(items: items);
  }

  // ---------- compact metric ----------
  Widget _metric(BuildContext context, IconData icon, String label, double value, Color color, VoidCallback onTap) => Pressable(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rLg), border: Border.all(color: C.border), boxShadow: C.shadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlossIcon(icon, color, size: 34),
            const SizedBox(height: 12),
            CountUp(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1)),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ---------- checklist ----------
  Widget _checklist(BuildContext context, OverviewStats s) {
    // (label, done, section to open)
    final tasks = <(String, bool, int)>[
      ('Set up your business profile', true, 10),
      ('Connect an account', s.linkedAccounts > 0, 8),
      ('Add your customers', s.customers > 0, 3),
      ('Send your first invitations', s.invitesSent > 0, 3),
      ('Collect your first testimonial', s.testimonials > 0, 1),
      ('Put your reviews on your website', s.embeds > 0, 6),
    ];
    final done = tasks.where((t) => t.$2).length;
    if (done == tasks.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AnimatedRing(
              progress: done / tasks.length,
              size: 52,
              stroke: 6,
              color: C.primary,
              track: C.surface2,
              child: Text('$done/${tasks.length}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Get started', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                SizedBox(height: 2),
                Muted('Finish setup to get more videos', size: 12.5),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          for (final t in tasks)
            InkWell(
              onTap: t.$2 ? null : () => shell.goTo(t.$3),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  AnimatedSwitcher(
                    duration: kMed,
                    transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
                    child: Icon(t.$2 ? PIconsFill.checkCircle : PIconsRegular.circle, key: ValueKey(t.$2), size: 22, color: t.$2 ? C.green : C.muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t.$1,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.$2 ? C.muted : C.text, decoration: t.$2 ? TextDecoration.lineThrough : null)),
                  ),
                  if (!t.$2) Icon(PIconsBold.caretRight, size: 14, color: C.muted),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A tall video card for the horizontal "stories" strip.
class _StoryCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  const _StoryCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [video.hue.withValues(alpha: 0.95), Color.lerp(video.hue, Colors.black, 0.55)!]),
            boxShadow: [BoxShadow(color: video.hue.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(children: [
            if (video.duration.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                  child: Text(video.duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
                child: Icon(video.written ? PIconsFill.quotes : PIconsFill.play, color: Colors.white, size: 24),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [for (var i = 0; i < 5; i++) Icon(i < video.rating ? PIconsFill.star : PIconsRegular.star, size: 12, color: const Color(0xFFFFC21A))]),
                const SizedBox(height: 6),
                Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(video.job, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75))),
              ]),
            ),
          ]),
        ),
      );
}


/// The row of quick-send buttons. Hold one and drop it on another to change the order; the order is remembered.
class _QuickActions extends StatefulWidget {
  final List<(IconData, String, Color, VoidCallback)> items;
  const _QuickActions({required this.items});
  @override
  State<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<_QuickActions> {
  static const _key = 'home_quick_order';
  late List<String> order = [for (final i in widget.items) i.$2];
  String? dragging, over;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getStringList(_key);
      final names = {for (final i in widget.items) i.$2};
      if (saved != null && saved.length == names.length && saved.every(names.contains) && mounted) setState(() => order = saved);
    }).catchError((_) {});
  }

  void _move(String from, String to) {
    if (from == to) return;
    final next = List.of(order);
    final fi = next.indexOf(from);
    next.removeAt(fi);
    next.insert(next.indexOf(to) + (fi < next.indexOf(to) ? 1 : 0), from);
    HapticFeedback.mediumImpact();
    setState(() => order = next);
    SharedPreferences.getInstance().then((p) => p.setStringList(_key, next)).catchError((_) => false);
  }

  Widget _tile((IconData, String, Color, VoidCallback) it, {bool lifted = false, bool target = false}) => Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: it.$3.withValues(alpha: C.dark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: it.$3.withValues(alpha: target ? 0.9 : 0.2), width: target ? 2 : 1),
            boxShadow: lifted ? [BoxShadow(color: it.$3.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))] : null,
          ),
          child: Icon(it.$1, color: it.$3, size: 26),
        ),
        const SizedBox(height: 7),
        Text(it.$2, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.muted)),
      ]);

  @override
  Widget build(BuildContext context) {
    final byName = {for (final i in widget.items) i.$2: i};
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (final name in order)
        _popIn(
          order.indexOf(name),
          DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data != name,
          onMove: (_) {
            if (over != name) setState(() => over = name);
          },
          onLeave: (_) {
            if (over == name) setState(() => over = null);
          },
          onAcceptWithDetails: (d) {
            setState(() => over = null);
            _move(d.data, name);
          },
          builder: (context, cand, _) => LongPressDraggable<String>(
            data: name,
            delay: const Duration(milliseconds: 240),
            hapticFeedbackOnStart: true,
            onDragStarted: () => setState(() => dragging = name),
            onDragEnd: (_) => setState(() {
              dragging = null;
              over = null;
            }),
            feedback: Material(
              color: Colors.transparent,
              child: Transform.scale(scale: 1.18, child: _tile(byName[name]!, lifted: true)),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: _tile(byName[name]!)),
            child: Pressable(
              onTap: byName[name]!.$4,
              scale: 0.92,
              child: AnimatedScale(
                scale: cand.isNotEmpty ? 1.12 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: _tile(byName[name]!, target: cand.isNotEmpty),
              ),
            ),
          ),
        ),
        ),
    ]);
  }

  /// The buttons pop in one after another when Home opens.
  Widget _popIn(int i, Widget w) => reduceMotion(context)
      ? w
      : w.animate(key: ValueKey('qa-${widget.items[i % widget.items.length].$2}'), delay: (180 + 80 * i).ms).scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 480.ms, curve: Curves.easeOutBack).fadeIn(duration: 260.ms);
}
