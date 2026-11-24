import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'motion.dart';
import 'theme.dart';

/// A calm "liquid" bottom bar.
/// The bar and a bubble are drawn as one blob of liquid (metaball effect): the bubble rises out of the bar
/// behind the chosen tab and, when you pick another tab, glides across slowly while a softer trailing blob
/// stretches a smooth neck behind it. A gentle wave flows through the bar and the bubble breathes slowly.
/// Everything is slow and smooth on purpose, so it feels soothing rather than bouncy.
///
/// [children] are [kSlots] equal-width slots (usually Expanded widgets) placed on the bar.
class LiquidNavBar extends StatefulWidget {
  final int selected; // slot index 0..4
  final List<Widget> children;
  const LiquidNavBar({super.key, required this.selected, required this.children});

  static const kSlots = 5;
  static const barHeight = 70.0;
  static const rise = 26.0; // room above the bar for the bubble
  static const totalHeight = barHeight + rise;

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000), value: 1);
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
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
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: LiquidNavBar.totalHeight,
        child: LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            return Stack(children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_move, _ambient]),
                      builder: (context, _) => CustomPaint(
                        painter: _LiquidPainter(
                          width: w,
                          from: _from,
                          to: _to,
                          move: _move.value,
                          ambient: _ambient.value,
                          dark: C.dark,
                          calm: reduceMotion(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, top: LiquidNavBar.rise, height: LiquidNavBar.barHeight, child: Row(children: widget.children)),
            ]);
          },
        ),
      );
}

class _LiquidPainter extends CustomPainter {
  final double width, move, ambient;
  final int from, to;
  final bool dark, calm;
  _LiquidPainter({required this.width, required this.from, required this.to, required this.move, required this.ambient, required this.dark, required this.calm});

  double _cx(int slot) => (slot + 0.5) * width / LiquidNavBar.kSlots;

  static const _gooMatrix = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 22, -2805, // alpha = 22 * alpha - 11 * 255: crisp edges where the blurred shapes overlap
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const rise = LiquidNavBar.rise;
    const barH = LiquidNavBar.barHeight;
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, rise, width, barH), const Radius.circular(34));

    // ---- where the liquid is
    final t = calm ? 1.0 : move.clamp(0.0, 1.0);
    final fx = _cx(from), tx = _cx(to);
    final lead = fx + (tx - fx) * Curves.easeInOutCubic.transform(((t - 0.0) / 0.78).clamp(0.0, 1.0));
    final trail = fx + (tx - fx) * Curves.easeInOutCubic.transform(((t - 0.16) / 0.84).clamp(0.0, 1.0));
    final breathe = calm ? 0.0 : math.sin(ambient * math.pi * 2 * 2.2) * 1.1; // slow breathing
    final float = calm ? 0.0 : math.sin(ambient * math.pi * 2 * 1.3) * 1.2;
    final r = 27.0 + breathe;
    final cy = rise + 7.0 + float;
    final moving = (tx - fx).abs() > 1 && t < 1;

    // ---- soft shadow under everything
    final shadowPaint = Paint()
      ..color = dark ? Colors.black.withValues(alpha: 0.55) : const Color(0xFF1B1550).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.save();
    canvas.translate(0, 9);
    canvas.drawRRect(bar, shadowPaint);
    canvas.drawCircle(Offset(lead, cy), r, shadowPaint);
    canvas.restore();

    // ---- the liquid body: bar + bubble + trailing blob, blurred then thresholded so they melt together
    final bodyColor = dark ? const Color(0xFF191928) : Colors.white;
    final blur = Paint()
      ..color = bodyColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.saveLayer(Rect.fromLTWH(-20, -20, width + 40, LiquidNavBar.totalHeight + 40), Paint()..colorFilter = const ColorFilter.matrix(_gooMatrix));
    canvas.drawRRect(bar, blur);
    canvas.drawCircle(Offset(lead, cy), r + 3, blur);
    if (moving) {
      // a smaller, lagging blob: stretches a smooth neck behind the bubble as it travels
      final k = math.sin(math.pi * t); // strongest mid-way
      canvas.drawCircle(Offset(trail, cy + 8), 15 + 5 * k, blur);
    }
    canvas.restore();

    // ---- thin edge light along the top of the bar
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dark ? const Color(0x14FFFFFF) : const Color(0xFFE6E6F1);
    canvas.drawRRect(bar.deflate(0.5), edge);

    // ---- a slow wave of colour flowing through the bar
    if (!calm) {
      canvas.save();
      canvas.clipRRect(bar);
      final phase = ambient * math.pi * 2;
      void wave(double base, double amp, double freq, double ph, double alpha) {
        final p = Path()..moveTo(0, rise + barH);
        for (double x = 0; x <= width; x += 4) {
          p.lineTo(x, rise + base + math.sin((x / width) * math.pi * 2 * freq + ph) * amp);
        }
        p
          ..lineTo(width, rise + barH)
          ..close();
        canvas.drawPath(p, Paint()..color = C.primary.withValues(alpha: alpha));
      }

      wave(barH * 0.8, 3.6, 1.4, phase, dark ? 0.10 : 0.07);
      wave(barH * 0.88, 3.0, 1.9, -phase * 1.2 + 1.0, dark ? 0.08 : 0.06);
      canvas.restore();
    }

    // ---- the bubble itself: soft glow, gradient, gentle light
    final c = Offset(lead, cy);
    canvas.drawCircle(c, r - 2, Paint()..color = C.primary.withValues(alpha: dark ? 0.45 : 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    final inner = Rect.fromCircle(center: c, radius: r - 3.5);
    canvas.drawCircle(
      c,
      r - 3.5,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9D86FF), Color(0xFF6A4CF0)]).createShader(inner),
    );
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 8), math.pi * 1.1, math.pi * 0.55, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_LiquidPainter o) => true;
}
