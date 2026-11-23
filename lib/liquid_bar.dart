import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'motion.dart';
import 'theme.dart';

/// A bottom bar with a "water" feel:
///  - a droplet that slides to the chosen tab, stretching as it moves and wobbling as it lands,
///  - ripples that spread from the exact spot you tap,
///  - a soft wave that flows along the bottom edge.
/// [children] must be [kSlots] equal-width slots (usually Expanded widgets).
class LiquidNavBar extends StatefulWidget {
  final int selected; // slot index 0..4
  final List<Widget> children;
  const LiquidNavBar({super.key, required this.selected, required this.children});

  static const kSlots = 5;

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _Ripple {
  final Offset pos;
  final AnimationController c;
  _Ripple(this.pos, this.c);
}

class _LiquidNavBarState extends State<LiquidNavBar> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 850), value: 1);
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  final List<_Ripple> _ripples = [];
  late int _from = widget.selected;
  late int _to = widget.selected;

  @override
  void didUpdateWidget(covariant LiquidNavBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _from = _to;
      _to = widget.selected;
      if (reduceMotion(context)) {
        _move.value = 1;
      } else {
        _move.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _wave.dispose();
    for (final r in _ripples) {
      r.c.dispose();
    }
    super.dispose();
  }

  void _addRipple(Offset p) {
    if (reduceMotion(context)) return;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    final r = _Ripple(p, c);
    _ripples.add(r);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _ripples.remove(r);
        c.dispose();
        if (mounted) setState(() {});
      }
    });
    c.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, cons) {
          final w = cons.maxWidth;
          final h = cons.maxHeight.isFinite ? cons.maxHeight : 70.0;
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _addRipple(e.localPosition),
            child: Stack(children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_move, _wave, ..._ripples.map((r) => r.c)]),
                      builder: (context, _) => CustomPaint(
                        painter: _LiquidPainter(
                          width: w,
                          height: h,
                          from: _from,
                          to: _to,
                          move: _move.value,
                          wave: _wave.value,
                          ripples: [for (final r in _ripples) (r.pos, r.c.value)],
                          color: C.primary,
                          dark: C.dark,
                          still: reduceMotion(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(children: widget.children),
            ]),
          );
        },
      );
}

class _LiquidPainter extends CustomPainter {
  final double width, height, move, wave;
  final int from, to;
  final List<(Offset, double)> ripples;
  final Color color;
  final bool dark, still;
  _LiquidPainter({required this.width, required this.height, required this.from, required this.to, required this.move, required this.wave, required this.ripples, required this.color, required this.dark, required this.still});

  double _cx(int slot) => (slot + 0.5) * width / LiquidNavBar.kSlots;

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 1. flowing wave along the bottom
    if (!still) {
      final phase = wave * math.pi * 2;
      void drawWave(double base, double amp, double freq, double ph, double alpha) {
        final path = Path()..moveTo(0, height);
        for (double x = 0; x <= width; x += 4) {
          path.lineTo(x, base + math.sin((x / width) * math.pi * 2 * freq + ph) * amp);
        }
        path
          ..lineTo(width, height)
          ..close();
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
      }

      drawWave(height * 0.84, 3.4, 1.7, phase, dark ? 0.12 : 0.09);
      drawWave(height * 0.9, 3.0, 2.3, -phase * 1.3 + 1.2, dark ? 0.09 : 0.07);
    }

    // ---- 2. ripples from taps
    for (final (pos, p) in ripples) {
      final e = Curves.easeOut.transform(p);
      final a = (1 - p).clamp(0.0, 1.0);
      canvas.drawCircle(pos, e * 76, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = color.withValues(alpha: 0.38 * a));
      canvas.drawCircle(pos, e * 50, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = color.withValues(alpha: 0.26 * a));
      canvas.drawCircle(pos, e * 62, Paint()..color = color.withValues(alpha: 0.09 * a));
    }

    // ---- 3. the water droplet behind the selected tab
    final cy = 29.0;
    final fx = _cx(from), tx = _cx(to);
    final t = move.clamp(0.0, 1.0);
    final lead = fx + (tx - fx) * Curves.easeOutBack.transform(t);
    final trailT = Curves.easeInOutCubic.transform(((t - 0.14) / 0.86).clamp(0.0, 1.0));
    final trail = fx + (tx - fx) * trailT;
    const halfW = 25.0;
    final left = math.min(lead, trail) - halfW;
    final right = math.max(lead, trail) + halfW;
    final squash = 5.0 * math.sin(math.pi * t);
    final wobble = t > 0.55 ? math.sin((t - 0.55) * math.pi * 7) * (1 - t) * 4.5 : 0.0;
    final hh = (35.0 - squash + wobble).clamp(24.0, 42.0);
    final rrect = RRect.fromLTRBR(left, cy - hh / 2, right, cy + hh / 2, Radius.circular(hh / 2));

    canvas.drawRRect(rrect.inflate(2), Paint()..color = color.withValues(alpha: dark ? 0.35 : 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11));
    canvas.drawRRect(
      rrect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: dark ? 0.42 : 0.3), color.withValues(alpha: dark ? 0.22 : 0.16)]).createShader(rrect.outerRect),
    );
    canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = color.withValues(alpha: 0.45));
    // little highlight, like light on a water drop
    final hl = Rect.fromLTWH(rrect.left + 9, rrect.top + 4.5, math.max(10.0, rrect.width * 0.34), 4.2);
    canvas.drawRRect(RRect.fromRectAndRadius(hl, const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: dark ? 0.22 : 0.5));
  }

  @override
  bool shouldRepaint(_LiquidPainter o) => true;
}
