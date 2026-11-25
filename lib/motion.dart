import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

/// True when the user asked their phone to reduce motion; every animation here respects it.
bool reduceMotion(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

/// Tap feedback: a quick scale-down and a light haptic tick.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  /// A soft coloured glow that blooms behind the child while it is pressed.
  final Color? glow;
  final double glowRadius;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = true, this.glow, this.glowRadius = 18});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  void _set(bool v) {
    if (widget.onTap == null) return;
    if (down != v) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: down && !reduceMotion(context) ? widget.scale : 1,
          duration: kFast,
          curve: kCurve,
          child: widget.glow == null
              ? widget.child
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: kCurve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.glowRadius),
                    boxShadow: down ? [BoxShadow(color: widget.glow!.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 3)] : const [],
                  ),
                  child: widget.child,
                ),
        ),
      );
}

/// Staggered entrance: fade in and rise slightly, one item after another.
extension Reveal on Widget {
  Widget reveal(BuildContext context, [int index = 0, double dy = 0.08]) {
    if (reduceMotion(context)) return this;
    return animate()
        .fadeIn(duration: 420.ms, delay: (55 * index).ms, curve: Curves.easeOut)
        .slideY(begin: dy, end: 0, duration: 520.ms, delay: (55 * index).ms, curve: kCurve);
  }
}

/// A number that counts up from zero when it first appears (and when it changes).
class CountUp extends StatelessWidget {
  final num value;
  final int decimals;
  final String prefix, suffix;
  final TextStyle? style;
  final Duration duration;
  const CountUp(this.value, {super.key, this.decimals = 0, this.prefix = '', this.suffix = '', this.style, this.duration = const Duration(milliseconds: 1100)});
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text('$prefix${value.toStringAsFixed(decimals)}$suffix', style: style);
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: kCurve,
      builder: (context, v, _) => Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// A ring that fills to [progress] (0..1) with a soft round cap.
class AnimatedRing extends StatelessWidget {
  final double progress, size, stroke;
  final Color color, track;
  final Widget? child;
  const AnimatedRing({super.key, required this.progress, this.size = 84, this.stroke = 8, required this.color, required this.track, this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0, 1)),
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 1200),
          curve: kCurve,
          builder: (context, v, _) => CustomPaint(painter: _RingPainter(v, stroke, color, track), child: Center(child: child)),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress, stroke;
  final Color color, track;
  _RingPainter(this.progress, this.stroke, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.color != color || o.track != track;
}

/// A smooth line chart that draws itself in, with a soft gradient fill underneath.
class Sparkline extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double height;
  const Sparkline({super.key, required this.values, required this.color, this.height = 64});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(painter: _SparkPainter(values, color, t)),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  final List<num> v;
  final Color color;
  final double t;
  _SparkPainter(this.v, this.color, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = v.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = v.reduce((a, b) => a < b ? a : b).toDouble();
    final span = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final pts = <Offset>[
      for (var i = 0; i < v.length; i++) Offset(size.width * i / (v.length - 1), size.height - 6 - (size.height - 14) * ((v[i] - minV) / span)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final mid = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(mid, pts[i].dy, mid, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    // Reveal left-to-right.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)]).createShader(Offset.zero & size),
    );
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round..color = color);
    canvas.restore();
    // End dot.
    if (t > 0.98) {
      canvas.drawCircle(pts.last, 5.5, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(pts.last, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.t != t || o.v != v || o.color != color;
}

/// A soft, slowly drifting glow used as an ambient background.
class AmbientGlow extends StatefulWidget {
  final Color color;
  final double size;
  const AmbientGlow({super.key, required this.color, this.size = 280});
  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform.translate(
            offset: Offset(-18 + 36 * t, 10 - 20 * t),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [widget.color.withValues(alpha: 0.55), widget.color.withValues(alpha: 0)]),
              ),
            ),
          );
        },
      );
}


// ---------------------------------------------------------------------------
// Motion kit (added): pop on change, confetti, parallax, music bars
// ---------------------------------------------------------------------------

/// Pops (grows slightly, then settles) whenever [value] changes. Used on badges and status labels.
class PopOnChange extends StatelessWidget {
  final Object value;
  final Widget child;
  const PopOnChange({super.key, required this.value, required this.child});
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: FadeTransition(opacity: a, child: c)),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// A short burst of coloured paper from the middle of the screen. Used for wins: sharing, approving, winning a lead.
void showConfetti(BuildContext context) {
  if (reduceMotion(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _ConfettiLayer(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _ConfettiLayer extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiLayer({required this.onDone});
  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward().whenComplete(widget.onDone);
  late final List<_Bit> _bits = _makeBits();

  static List<_Bit> _makeBits() {
    final r = math.Random();
    const colors = [Color(0xFF9378FF), Color(0xFFFF4F9A), Color(0xFFFFB84D), Color(0xFF2DD4A0), Color(0xFF5AB0FF)];
    return [
      for (var i = 0; i < 34; i++)
        _Bit(
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * 2.2,
          speed: 260 + r.nextDouble() * 360,
          spin: (r.nextDouble() - 0.5) * 12,
          size: 6 + r.nextDouble() * 6,
          color: colors[i % colors.length],
          round: i % 3 == 0,
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c, _bits)));
}

class _Bit {
  final double angle, speed, spin, size;
  final Color color;
  final bool round;
  _Bit({required this.angle, required this.speed, required this.spin, required this.size, required this.color, required this.round});
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final List<_Bit> bits;
  _ConfettiPainter(this.t, this.bits) : super(repaint: t);
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.52);
    final time = t.value * 1.7; // seconds
    for (final b in bits) {
      final x = origin.dx + math.cos(b.angle) * b.speed * time * (1 - t.value * 0.35);
      final y = origin.dy + math.sin(b.angle) * b.speed * time + 620 * time * time * 0.5;
      final fade = t.value < 0.7 ? 1.0 : (1 - (t.value - 0.7) / 0.3);
      final p = Paint()..color = b.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * time);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, p);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55), const Radius.circular(1.5)), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => false;
}

/// Moves its child a little slower than the page scrolls, so photos and videos drift as you scroll.
class Parallax extends StatefulWidget {
  final Widget child;
  final double strength; // pixels of drift at the edges of the screen
  const Parallax({super.key, required this.child, this.strength = 16});
  @override
  State<Parallax> createState() => _ParallaxState();
}

class _ParallaxState extends State<Parallax> {
  final _dy = ValueNotifier<double>(0);
  ScrollPosition? _pos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pos?.removeListener(_update);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final scrollBox = Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || scrollBox == null || !box.attached || !box.hasSize || !scrollBox.hasSize) return;
    final y = box.localToGlobal(box.size.center(Offset.zero), ancestor: scrollBox).dy;
    final h = scrollBox.size.height;
    _dy.value = ((y - h / 2) / h).clamp(-1.0, 1.0) * widget.strength;
  }

  @override
  void dispose() {
    _pos?.removeListener(_update);
    _dy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return ClipRect(
      child: ValueListenableBuilder<double>(
        valueListenable: _dy,
        child: RepaintBoundary(child: widget.child),
        builder: (_, v, c) => Transform.translate(offset: Offset(0, v), child: Transform.scale(scale: 1.1, child: c)),
      ),
    );
  }
}

/// Small bouncing bars, like a music player. Moves while [active], rests flat otherwise.
class MusicBars extends StatefulWidget {
  final bool active;
  final Color color;
  final double height;
  const MusicBars({super.key, required this.active, this.color = Colors.white, this.height = 14});
  @override
  State<MusicBars> createState() => _MusicBarsState();
}

class _MusicBarsState extends State<MusicBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(MusicBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: 22,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 3.2,
                height: widget.active ? widget.height * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(_c.value * math.pi * 2 + i * 1.7)).abs()) : widget.height * 0.3,
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ),
      );
}

/// A few soft dots that drift slowly in the background of a screen.
class FloatingDots extends StatelessWidget {
  final int count;
  const FloatingDots({super.key, this.count = 9});
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    final r = math.Random(7);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => Stack(children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: r.nextDouble() * box.maxWidth,
              top: r.nextDouble() * box.maxHeight,
              child: Container(
                width: 4 + r.nextDouble() * 6,
                height: 4 + r.nextDouble() * 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: C.primary.withValues(alpha: 0.10 + r.nextDouble() * 0.14)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true), delay: (r.nextInt(2400)).ms)
                  .moveY(begin: -10, end: 14, duration: (3200 + r.nextInt(2600)).ms, curve: Curves.easeInOut)
                  .fade(begin: 0.35, end: 1, duration: 2400.ms),
            ),
        ]),
      ),
    );
  }
}
