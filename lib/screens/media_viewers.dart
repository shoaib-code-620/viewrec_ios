import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../media_data.dart';
import 'media_create.dart';
import '../repo.dart';
import '../widgets.dart';
import 'media_widgets.dart';

// ===========================================================================
// Stories
// ===========================================================================

/// Full-screen stories: progress bars, tap left/right to move, hold to pause, swipe down to close.
class StoryViewer extends StatefulWidget {
  final List<StoryGroup> groups; // only groups that have stories
  final int startIndex;
  const StoryViewer({super.key, required this.groups, this.startIndex = 0});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int g = widget.startIndex;
  int i = 0;
  late final AnimationController _p = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  final reply = TextEditingController();
  final focus = FocusNode();
  bool liked = false;

  StoryGroup get group => widget.groups[g];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    focus.addListener(() {
      if (focus.hasFocus) {
        _p.stop();
      } else {
        _p.forward();
      }
    });
    _open();
  }

  void _open() {
    group.seen = true;
    repo.markStorySeen(group.id).catchError((_) {});
    _p.forward(from: 0);
  }

  void _next() {
    if (i < group.items.length - 1) {
      setState(() => i++);
      _p.forward(from: 0);
    } else if (g < widget.groups.length - 1) {
      setState(() {
        g++;
        i = 0;
        liked = false;
      });
      _open();
    } else {
      _close();
    }
  }

  void _prev() {
    if (i > 0) {
      setState(() => i--);
      _p.forward(from: 0);
    } else if (g > 0) {
      setState(() {
        g--;
        i = widget.groups[g].items.length - 1;
      });
      _p.forward(from: 0);
    } else {
      _p.forward(from: 0);
    }
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _p.dispose();
    reply.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = group.items[i];
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.globalPosition.dx < w / 3 ? _prev() : _next(),
        onLongPressStart: (_) => _p.stop(),
        onLongPressEnd: (_) => _p.forward(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) _close();
        },
        child: Stack(children: [
          // the slide
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: Container(
                key: ValueKey('${group.id}-$i'),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [item.hue, Color.lerp(item.hue, Colors.black, 0.7)!])),
                child: item.mediaPath != null
                    ? Stack(fit: StackFit.expand, children: [
                        MediaView(path: item.mediaPath, isVideo: item.isVideo, hue: item.hue, play: true, sound: true, edits: item.edits),
                        if (item.text.isNotEmpty)
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 120,
                            child: Text(item.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
                          ),
                      ])
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text(item.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white)),
                        ),
                      ),
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(children: [
                  for (var k = 0; k < group.items.length; k++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                        child: k < i
                            ? Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))
                            : k == i
                                ? AnimatedBuilder(
                                    animation: _p,
                                    builder: (context, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _p.value, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
                                  )
                                : null,
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                child: Row(children: [
                  Avatar(group.business, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(group.business, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white))),
                        const SizedBox(width: 6),
                        Text(item.when, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.7))),
                      ]),
                      Text(group.category, style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.7))),
                    ]),
                  ),
                  IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded, color: Colors.white)),
                ]),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: reply,
                      focusNode: focus,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) {
                        if (reply.text.trim().isNotEmpty) {
                          showMsg(context, 'Reply sent');
                          reply.clear();
                        }
                        focus.unfocus();
                      },
                      decoration: InputDecoration(
                        hintText: 'Reply to ${group.business}…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => liked = !liked);
                    },
                    icon: AnimatedScale(scale: liked ? 1.2 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? const Color(0xFFFF4F6A) : Colors.white, size: 28)),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Reels
// ===========================================================================

/// Full-screen vertical reels: swipe up for the next one, tap to pause, double-tap to like.
class ReelsViewer extends StatefulWidget {
  final List<Reel> reels;
  final int startIndex;
  final VoidCallback onChanged;
  const ReelsViewer({super.key, required this.reels, this.startIndex = 0, required this.onChanged});
  @override
  State<ReelsViewer> createState() => _ReelsViewerState();
}

class _ReelsViewerState extends State<ReelsViewer> {
  late final PageController _pc = PageController(initialPage: widget.startIndex);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pc.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.reels.length,
            itemBuilder: (context, i) => _ReelPage(reel: widget.reels[i], all: widget.reels, onChanged: _refresh),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Text('Reels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      );
}

class _ReelPage extends StatefulWidget {
  final Reel reel;
  final List<Reel> all;
  final VoidCallback onChanged;
  const _ReelPage({required this.reel, required this.all, required this.onChanged});
  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(vsync: this, duration: Duration(seconds: durationSeconds(widget.reel.duration).clamp(8, 90)))..repeat();
  bool playing = true;
  int burst = 0;

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => playing = !playing);
    if (playing) {
      _p.repeat();
    } else {
      _p.stop();
    }
  }

  void _like() {
    setState(() => burst++);
    MediaActions.toggleLike(context, widget.reel, widget.onChanged, force: true);
  }

  Widget _rail(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white, bool bounce = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(children: [
            AnimatedScale(scale: bounce ? 1.18 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Icon(icon, size: 31, color: color)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      onDoubleTap: _like,
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [r.hue, Color.lerp(r.hue, Colors.black, 0.75)!])),
        child: Stack(children: [
          if (r.mediaPath != null) Positioned.fill(child: MediaView(path: r.mediaPath, isVideo: r.isVideo, hue: r.hue, play: playing, sound: true, edits: r.edits)),
          // play / pause mark
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: playing ? 0.0 : 1.0,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                child: const Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white),
              ),
            ),
          ),
          if (burst > 0)
            Center(
              child: const Icon(Icons.favorite_rounded, size: 110, color: Colors.white)
                  .animate(key: ValueKey(burst))
                  .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.1, 1.1), duration: 380.ms, curve: Curves.easeOutBack)
                  .then(delay: 250.ms)
                  .fadeOut(duration: 350.ms),
            ),
          // bottom shade
          Positioned(left: 0, right: 0, bottom: 0, height: 320, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)])))),
          // actions
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(children: [
              _rail(r.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, compact(r.likes), () => MediaActions.toggleLike(context, r, widget.onChanged), color: r.liked ? const Color(0xFFFF4F6A) : Colors.white, bounce: r.liked),
              _rail(Icons.chat_bubble_outline_rounded, compact(r.comments), () => showCommentsSheet(context, r, widget.onChanged)),
              _rail(Icons.ios_share_rounded, 'Share', () => MediaActions.share(context, r)),
              _rail(r.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, r.saved ? 'Saved' : 'Save', () => MediaActions.toggleSave(context, r, widget.onChanged), bounce: r.saved),
            ]),
          ),
          // info
          Positioned(
            left: 16,
            right: 84,
            bottom: 52,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Avatar(r.business, size: 40),
                const SizedBox(width: 10),
                Flexible(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(r.business, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
                    if (r.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: Color(0xFF7CC4FF))),
                  ]),
                ),
                const SizedBox(width: 10),
                FollowButton(following: r.following, onDark: true, onTap: () => MediaActions.toggleFollow(context, r, widget.all, widget.onChanged)),
              ]),
              const SizedBox(height: 12),
              Text(r.caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                for (var k = 0; k < 5; k++) Icon(k < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: const Color(0xFFFFD25E)),
                const SizedBox(width: 8),
                Flexible(child: Text('${r.reviewer} · ${r.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)))),
              ]),
            ]),
          ),
          // progress
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _p,
              builder: (context, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _p.value, child: Container(height: 3, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
