import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../media_data.dart';
import 'media_create.dart';
import 'media_explore.dart';
import 'media_profile.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

String compact(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

int durationSeconds(String d) {
  final p = d.split(':');
  if (p.length != 2) return 30;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 30);
}

/// Follow / Following pill that morphs smoothly between the two states.
class FollowButton extends StatelessWidget {
  final bool following;
  final VoidCallback onTap;
  final bool onDark; // on top of a video (white text, frosted)
  const FollowButton({super.key, required this.following, required this.onTap, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final fg = following ? (onDark ? Colors.white : C.text) : Colors.white;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: following ? null : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E94F5), Color(0xFF0B5FC4)]),
          color: following ? (onDark ? Colors.white.withValues(alpha: 0.18) : C.surface2) : null,
          border: following ? Border.all(color: onDark ? Colors.white.withValues(alpha: 0.35) : C.border) : null,
          boxShadow: following ? null : [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(following ? Icons.check_rounded : Icons.add_rounded, key: ValueKey(following), size: 15, color: fg),
            ),
            const SizedBox(width: 4),
            Text(following ? 'Following' : 'Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// A story circle: a slowly turning colourful ring for new stories, a calm grey ring once seen.
class StoryRing extends StatefulWidget {
  final String name;
  final bool seen, mine;
  final VoidCallback onTap;
  const StoryRing({super.key, required this.name, required this.seen, required this.mine, required this.onTap});
  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !widget.seen && !widget.mine && !reduceMotion(context);
    return Pressable(
      onTap: widget.onTap,
      scale: 0.94,
      child: SizedBox(
        width: 78,
        child: Column(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  size: const Size(72, 72),
                  painter: _RingPainter(rotation: animate ? _c.value * math.pi * 2 : 0.6, seen: widget.seen, mine: widget.mine),
                ),
              ),
              Avatar(widget.mine ? 'Hartley Roofing' : widget.name, size: 58),
              if (widget.mine)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: C.primary, border: Border.all(color: C.bg, width: 2.5)),
                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 7),
          Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: widget.seen ? FontWeight.w500 : FontWeight.w700, color: widget.seen ? C.muted : C.text)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double rotation;
  final bool seen, mine;
  _RingPainter({required this.rotation, required this.seen, required this.mine});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = seen || mine ? 2 : 3.2
      ..strokeCap = StrokeCap.round;
    if (seen || mine) {
      p.color = mine ? C.border : C.border.withValues(alpha: 1);
    } else {
      p.shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: const [Color(0xFF0B5FC4), Color(0xFFFF6B5E), Color(0xFFFFC21A), Color(0xFF0B5FC4)],
      ).createShader(rect);
    }
    canvas.drawOval(rect, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.rotation != rotation || o.seen != seen || o.mine != mine;
}

/// Likes, saves, follows and shares for a reel. Updates the screen straight away and rolls back if the server refuses.
class MediaActions {
  static Future<void> toggleFollow(BuildContext context, Reel r, List<Reel> all, VoidCallback refresh) async {
    final next = !r.following;
    for (final x in all.where((x) => x.businessId == r.businessId)) {
      x.following = next;
    }
    refresh();
    try {
      await repo.setFollow(r.businessId, next);
    } catch (_) {
      for (final x in all.where((x) => x.businessId == r.businessId)) {
        x.following = !next;
      }
      refresh();
      if (context.mounted) showMsg(context, "Couldn't update that. Try again.");
    }
  }

  static Future<void> toggleLike(BuildContext context, Reel r, VoidCallback refresh, {bool? force}) async {
    final next = force ?? !r.liked;
    if (r.liked == next) return;
    HapticFeedback.lightImpact();
    r.liked = next;
    r.likes += next ? 1 : -1;
    refresh();
    try {
      await repo.setLike(r.id, next);
    } catch (_) {
      r.liked = !next;
      r.likes += next ? -1 : 1;
      refresh();
      if (context.mounted) showMsg(context, "Couldn't update that. Try again.");
    }
  }

  static Future<void> toggleSave(BuildContext context, Reel r, VoidCallback refresh) async {
    final next = !r.saved;
    r.saved = next;
    refresh();
    try {
      await repo.setSave(r.id, next);
      if (context.mounted) showMsg(context, next ? 'Saved to your collection' : 'Removed from saved');
    } catch (_) {
      r.saved = !next;
      refresh();
    }
  }

  static void share(BuildContext context, Reel r) {
    Clipboard.setData(ClipboardData(text: 'https://viewrec.com/media/${r.id}'));
    showMsg(context, 'Link copied');
  }
}

/// Comments for one reel, with a box to add yours.
void showCommentsSheet(BuildContext context, Reel reel, VoidCallback onChanged) {
  showSheet(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const H2('Comments'),
        const SizedBox(width: 8),
        Text('${reel.comments}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      _CommentsBody(reel: reel, onChanged: onChanged),
    ]),
  );
}

/// A caption like Instagram's: the business name first, #hashtags and @mentions in blue and tappable, and "more" for long text.
class CaptionText extends StatefulWidget {
  final String name, text;
  final bool onDark;
  final double size;
  const CaptionText({super.key, required this.name, required this.text, this.onDark = false, this.size = 14});
  @override
  State<CaptionText> createState() => _CaptionTextState();
}

class _CaptionTextState extends State<CaptionText> {
  bool open = false;
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final base = TextStyle(fontSize: widget.size, height: 1.4, color: widget.onDark ? Colors.white : C.text);
    final link = base.copyWith(color: widget.onDark ? const Color(0xFF8CC3FF) : C.primary, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[TextSpan(text: '${widget.name}  ', style: base.copyWith(fontWeight: FontWeight.w800))];
    for (final m in RegExp(r'(#\w+|@\w+|[^#@]+|[#@])').allMatches(widget.text)) {
      final w = m.group(0)!;
      if (w.length > 1 && w.startsWith('#')) {
        final r = TapGestureRecognizer()..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HashtagScreen(tag: w.substring(1))));
        _taps.add(r);
        spans.add(TextSpan(text: w, style: link, recognizer: r));
      } else if (w.length > 1 && w.startsWith('@')) {
        spans.add(TextSpan(text: w, style: link));
      } else {
        spans.add(TextSpan(text: w));
      }
    }
    final long = widget.text.length > 90;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: long ? () => setState(() => open = !open) : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topLeft,
        child: Text.rich(TextSpan(style: base, children: spans), maxLines: open ? null : 2, overflow: open ? TextOverflow.visible : TextOverflow.ellipsis),
      ),
    );
  }
}

class _CommentsBody extends StatefulWidget {
  final Reel reel;
  final VoidCallback onChanged;
  const _CommentsBody({required this.reel, required this.onChanged});
  @override
  State<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends State<_CommentsBody> {
  final input = TextEditingController();
  final focus = FocusNode();
  /// Comments you liked on this phone.
  final liked = <String>{};
  List<Comment>? list;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    repo.comments(widget.reel.id).then((v) {
      if (mounted) setState(() => list = v);
    }).catchError((_) {
      if (mounted) setState(() => list = []);
    });
  }

  @override
  void dispose() {
    focus.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final c = await repo.addComment(widget.reel.id, t);
      if (!mounted) return;
      setState(() {
        list = [...?list, c];
        input.clear();
      });
      widget.onChanged();
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't post your comment. Try again.");
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 300,
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list!.isEmpty
                  ? const EmptyState(Icons.chat_bubble_outline_rounded, 'No comments yet', 'Be the first to say something.')
                  : ListView(children: [
                      for (final c in list!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Avatar(c.author, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(c.author, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Text(c.when, style: TextStyle(fontSize: 12, color: C.muted)),
                                ]),
                                const SizedBox(height: 2),
                                Text(c.text, style: const TextStyle(fontSize: 14, height: 1.35)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  if (c.id.hashCode % 9 + (liked.contains(c.id) ? 1 : 0) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 14),
                                      child: Text('${c.id.hashCode % 9 + (liked.contains(c.id) ? 1 : 0)} likes', style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
                                    ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      input.text = '@${c.author.split(' ').first} ';
                                      input.selection = TextSelection.collapsed(offset: input.text.length);
                                      focus.requestFocus();
                                    },
                                    child: Text('Reply', style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w800)),
                                  ),
                                ]),
                              ]),
                            ),
                            GestureDetector(
                              key: ValueKey('like_${c.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => liked.contains(c.id) ? liked.remove(c.id) : liked.add(c.id)),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 2, 0, 8),
                                child: AnimatedScale(
                                  scale: liked.contains(c.id) ? 1.2 : 1,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  child: Icon(liked.contains(c.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: liked.contains(c.id) ? const Color(0xFFE5484D) : C.muted),
                                ),
                              ),
                            ),
                            if (c.author != 'You')
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => showReportSheet(context, targetType: 'comment', targetId: c.id, subject: 'this comment'),
                                child: Padding(padding: const EdgeInsets.fromLTRB(8, 2, 0, 8), child: Icon(Icons.flag_outlined, size: 17, color: C.muted)),
                              ),
                          ]),
                        ),
                    ]),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: input,
              focusNode: focus,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: TextStyle(color: C.muted),
                filled: true,
                fillColor: C.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: sending ? null : _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF3E94F5), Color(0xFF0B5FC4)])),
              child: sending ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
            ),
          ),
        ]),
      ]);
}

/// The "+" menu: what do you want to create?
void showCreateSheet(BuildContext context) {
  final items = <(IconData, String, String, Color)>[
    (Icons.grid_on_rounded, 'Post', 'Share a photo or video with a caption', const Color(0xFF3E94F5)),
    (Icons.movie_creation_rounded, 'Reel', 'A short vertical video customers can follow', const Color(0xFFFF6B5E)),
    (Icons.auto_stories_rounded, 'Story', 'Disappears after 24 hours', const Color(0xFFFFC21A)),
  ];
  showSheet(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H2('Create'),
      const SizedBox(height: 4),
      const Muted('Share something with your followers.', size: 13),
      const SizedBox(height: 16),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComposeScreen(kind: const ['post', 'reel', 'story'][i])));
            },
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: items[i].$4.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
                child: Icon(items[i].$1, color: items[i].$4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Muted(items[i].$3, size: 12.5),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ).reveal(context, i, 0.1),
        ),
    ]),
  );
}
