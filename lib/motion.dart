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
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = true});
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
          child: widget.child,
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
