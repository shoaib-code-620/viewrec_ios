import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../media_data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'media_create.dart';
import 'media_viewers.dart';
import 'media_widgets.dart';

/// Media: stories of other businesses on top, then a feed of customer video testimonials (reels).
class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  Future<(List<StoryGroup>, List<Reel>)> _load() async => (await repo.stories(), await repo.reels());

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: mediaRevision,
        // A new revision (something was posted) rebuilds the view, which reloads the feed.
        builder: (context, rev, _) => AsyncView<(List<StoryGroup>, List<Reel>)>(
          key: ValueKey(rev),
          load: _load,
          builder: (context, data, refresh) => RefreshIndicator(
            color: C.primary,
            onRefresh: refresh,
            child: _MediaBody(stories: data.$1, reels: data.$2),
          ),
        ),
      );
}

/// The row of story circles. Used on Home and Media; tapping one opens the story viewer.
class StoriesRow extends StatefulWidget {
  final List<StoryGroup> stories;
  final EdgeInsets padding;
  const StoriesRow({super.key, required this.stories, this.padding = EdgeInsets.zero});
  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  void _openStory(StoryGroup g) {
    if (g.mine && g.items.isEmpty) {
      showCreateSheet(context);
      return;
    }
    final playable = widget.stories.where((s) => s.items.isNotEmpty).toList();
    final start = playable.indexOf(g);
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => StoryViewer(groups: playable, startIndex: start < 0 ? 0 : start),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child)),
    )).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: widget.padding,
          clipBehavior: Clip.none,
          itemCount: widget.stories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final g = widget.stories[i];
            final ring = StoryRing(name: g.business, seen: g.seen, mine: g.mine, onTap: () => _openStory(g)).reveal(context, i, 0.1);
            // A new story gives one small pulse so the eye finds it.
            if (g.seen || g.mine || reduceMotion(context)) return ring;
            return ring.animate(key: ValueKey('pulse-${g.id}'), delay: (700 + 140 * i).ms).scaleXY(begin: 1, end: 1.09, duration: 260.ms, curve: Curves.easeOut).then().scaleXY(begin: 1.09, end: 1, duration: 420.ms, curve: Curves.easeInOut);
          },
        ),
      );
}

class _MediaBody extends StatefulWidget {
  final List<StoryGroup> stories;
  final List<Reel> reels;
  const _MediaBody({required this.stories, required this.reels});
  @override
  State<_MediaBody> createState() => _MediaBodyState();
}

class _MediaBodyState extends State<_MediaBody> {
  int tab = 0; // 0 For you, 1 Following

  List<Reel> get _visible => tab == 0 ? widget.reels : widget.reels.where((r) => r.following).toList();

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openReel(List<Reel> list, Reel r) {
    // The player grows out of the feed and fades in, instead of sliding across.
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => ReelsViewer(reels: list, startIndex: list.indexOf(r), onChanged: _refresh),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
      ),
    )).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    var n = 0;
    return AppPage(reveal: false, hPad: 0, children: [
      StoriesRow(stories: widget.stories, padding: const EdgeInsets.symmetric(horizontal: 18)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: LiquidPills(const ['For you', 'Following'], tab, (i) => setState(() => tab = i)),
      ).reveal(context, n++),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: kMed,
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: c)),
        child: Column(key: ValueKey(tab), children: [
          if (tab == 1 && list.isEmpty) _followingEmpty(context),
          for (var i = 0; i < list.length; i++)
            _ReelCard(reel: list[i], all: widget.reels, onChanged: _refresh, onOpen: () => _openReel(list, list[i])).reveal(context, 2 + i, 0.08),
        ]),
      ),
    ]);
  }

  Widget _followingEmpty(BuildContext context) {
    final seen = <String>{};
    final suggestions = widget.reels.where((r) => !r.following && seen.add(r.businessId)).take(6).toList();
    return Column(children: [
      const EmptyState(Icons.people_alt_rounded, 'Nothing here yet', 'Follow businesses to see their reels here.'),
      for (final r in suggestions)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: AppCard(
            child: Row(children: [
              Avatar(r.business, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.business, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Muted(r.category, size: 12, maxLines: 1),
                ]),
              ),
              FollowButton(following: r.following, onTap: () => MediaActions.toggleFollow(context, r, widget.reels, _refresh)),
            ]),
          ),
        ),
    ]);
  }
}

class _ReelCard extends StatefulWidget {
  final Reel reel;
  final List<Reel> all;
  final VoidCallback onChanged, onOpen;
  const _ReelCard({required this.reel, required this.all, required this.onChanged, required this.onOpen});
  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  int burst = 0;

  void _like() {
    setState(() => burst++);
    MediaActions.toggleLike(context, widget.reel, widget.onChanged, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    // Instagram-style post: full width, no card, just a thin divider between posts.
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      padding: const EdgeInsets.only(bottom: 6),
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(children: [
            Avatar(r.business, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(r.business, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                  if (r.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 15, color: C.blue)),
                ]),
                Text(r.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 8),
            FollowButton(following: r.following, onTap: () => MediaActions.toggleFollow(context, r, widget.all, widget.onChanged)),
            const SizedBox(width: 2),
            Icon(Icons.more_horiz_rounded, color: C.muted),
          ]),
        ),
        // the video
        GestureDetector(
          onTap: widget.onOpen,
          onDoubleTap: _like,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [r.hue, Color.lerp(r.hue, Colors.black, 0.65)!])),
              child: Stack(children: [
                if (r.mediaPath != null) Positioned.fill(child: Parallax(child: MediaView(path: r.mediaPath, isVideo: r.isVideo, hue: r.hue, edits: r.edits))),
                if (r.mediaPath == null || r.isVideo)
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.38))),
                    child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(r.kind == 'post' ? Icons.grid_on_rounded : Icons.movie_creation_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(r.kind == 'post' ? (r.isVideo ? 'Post · ${r.duration}' : 'Post') : 'Reel · ${r.duration}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.visibility_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(compact(r.views), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, height: 120, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)])))),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(children: [
                    if (r.rating > 0) ...[
                      for (var k = 0; k < 5; k++) Icon(k < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: const Color(0xFFFFD25E)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(r.reviewer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white))),
                    if (r.isVideo) const Icon(Icons.volume_off_rounded, size: 18, color: Colors.white70),
                  ]),
                ),
                if (burst > 0)
                  Center(
                    child: const Icon(Icons.favorite_rounded, size: 100, color: Colors.white)
                        .animate(key: ValueKey(burst))
                        .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.1, 1.1), duration: 380.ms, curve: Curves.easeOutBack)
                        .then(delay: 250.ms)
                        .fadeOut(duration: 350.ms),
                  ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 0),
          child: Row(children: [
            _action(r.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, () {
              if (!r.liked) setState(() => burst++);
              MediaActions.toggleLike(context, r, widget.onChanged);
            }, color: r.liked ? const Color(0xFFFF4F6A) : C.text, bounce: r.liked),
            _action(Icons.chat_bubble_outline_rounded, () => showCommentsSheet(context, r, widget.onChanged)),
            _action(Icons.ios_share_rounded, () => MediaActions.share(context, r)),
            const Spacer(),
            _action(r.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, () => MediaActions.toggleSave(context, r, widget.onChanged), bounce: r.saved, color: r.saved ? C.primary : C.text),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: c)),
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
              child: Text('${compact(r.likes)} likes', key: ValueKey(r.likes), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${r.business}  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: r.caption),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => showCommentsSheet(context, r, widget.onChanged),
              child: Text(r.comments == 0 ? 'Add a comment' : 'View all ${r.comments} comments', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _action(IconData icon, VoidCallback onTap, {Color? color, bool bounce = false}) => Pressable(
        onTap: onTap,
        scale: 0.85,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedScale(scale: bounce ? 1.18 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Icon(icon, size: 27, color: color ?? C.text)),
        ),
      );
}
