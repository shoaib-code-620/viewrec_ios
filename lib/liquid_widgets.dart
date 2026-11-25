import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Calm, liquid-feeling building blocks used across the app.
// Everything is slow and smooth on purpose, and turns still when "reduce motion" is on.
// ---------------------------------------------------------------------------

/// Slowly drifting pools of colour behind a page, like light moving through water.
class LiquidBackdrop extends StatefulWidget {
  const LiquidBackdrop({super.key});
  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _BackdropPainter(still ? 0.2 : _c.value, C.dark), size: Size.infinite),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double t;
  final bool dark;
  _BackdropPainter(this.t, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = t * math.pi * 2;
    void pool(Offset c, double r, Color color, double alpha) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]).createShader(rect));
    }

    // The design's soft glows: teal at the top right, yellow on the left, coral at the bottom right.
    final k = dark ? 0.55 : 1.0;
    pool(Offset(w * (1.0 + 0.06 * math.sin(a)), h * (0.10 + 0.04 * math.cos(a * 1.3))), w * 0.80, const Color(0xFF3DE0BC), 0.18 * k);
    pool(Offset(w * (0.0 + 0.06 * math.cos(a * 0.8)), h * (0.46 + 0.06 * math.sin(a))), w * 0.78, const Color(0xFFFFC21A), 0.18 * k);
    pool(Offset(w * (1.0 + 0.05 * math.sin(a * 1.1 + 1)), h * (0.80 + 0.04 * math.cos(a))), w * 0.75, const Color(0xFFFF6B5E), 0.14 * k);
  }

  @override
  bool shouldRepaint(_BackdropPainter o) => o.t != t || o.dark != dark;
}

/// A progress bar that fills like liquid: the leading edge ripples gently and a soft light drifts through it.
/// (Same parameter names as LinearProgressIndicator so it is a drop-in replacement.)
class LiquidProgress extends StatefulWidget {
  final double? value; // 0..1
  final double minHeight;
  final Color? backgroundColor;
  final Color? color;
  const LiquidProgress({super.key, this.value, this.minHeight = 8, this.backgroundColor, this.color});
  @override
  State<LiquidProgress> createState() => _LiquidProgressState();
}

class _LiquidProgressState extends State<LiquidProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = (widget.value ?? 0.0).clamp(0.0, 1.0);
    final still = reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: still ? Duration.zero : const Duration(milliseconds: 1400),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) => SizedBox(
        height: widget.minHeight,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _ProgressPainter(v, still ? 0 : _c.value, widget.backgroundColor ?? C.surface2, widget.color ?? C.primary)),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double v, t;
  final Color track, color;
  _ProgressPainter(this.v, this.t, this.track, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(rrect, Paint()..color = track);
    if (v <= 0) return;
    canvas.save();
    canvas.clipRRect(rrect);
    final fillW = size.width * v;
    final amp = math.min(size.height * 0.28, 3.0);
    final phase = t * math.pi * 2;
    // Fill whose leading edge is a soft moving wave.
    final path = Path()..moveTo(0, 0);
    path.lineTo(math.max(0, fillW - amp), 0);
    for (double y = 0; y <= size.height; y += 1) {
      path.lineTo(fillW + math.sin((y / size.height) * math.pi * 2 + phase * 2) * amp, y);
    }
    path
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..shader = LinearGradient(colors: [color.withValues(alpha: 0.85), color]).createShader(Rect.fromLTWH(0, 0, math.max(fillW, 1), size.height)),
    );
    // Light drifting through the liquid.
    final bx = (t * (fillW + 60)) - 30;
    canvas.drawRect(
      Rect.fromLTWH(bx - 24, 0, 48, size.height),
      Paint()..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromLTWH(bx - 24, 0, 48, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProgressPainter o) => o.v != v || o.t != t || o.color != color || o.track != track;
}

/// A switch whose knob stretches like liquid as it travels from one side to the other.
class LiquidSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const LiquidSwitch({super.key, required this.value, this.onChanged});
  @override
  State<LiquidSwitch> createState() => _LiquidSwitchState();
}

class _LiquidSwitchState extends State<LiquidSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: widget.value ? 1 : 0);
  @override
  void didUpdateWidget(covariant LiquidSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (reduceMotion(context)) {
        _c.value = widget.value ? 1 : 0;
      } else {
        _c.animateTo(widget.value ? 1 : 0, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 54.0, h = 32.0, pad = 3.5, knob = h - pad * 2;
    return Semantics(
      toggled: widget.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onChanged!(!widget.value);
              },
        child: Opacity(
          opacity: widget.onChanged == null ? 0.5 : 1,
          child: SizedBox(
            width: w + 6,
            height: h + 6,
            child: Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final p = _c.value;
                  final stretch = 14 * math.sin(math.pi * p);
                  final left = pad + (w - pad * 2 - knob) * p - stretch * (1 - p);
                  final width = knob + stretch;
                  return Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(h / 2),
                      color: Color.lerp(C.surface2, C.primary, p),
                      border: Border.all(color: Color.lerp(C.border, C.primary, p)!),
                      boxShadow: p > 0.01 ? [BoxShadow(color: C.primary.withValues(alpha: 0.28 * p), blurRadius: 14, offset: const Offset(0, 5))] : null,
                    ),
                    child: Stack(children: [
                      Positioned(
                        left: left.clamp(pad - 8, w),
                        top: pad - 1,
                        width: width,
                        height: knob,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(knob / 2), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))]),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter pills in one soft track, with a liquid highlight that stretches and glides to the chosen pill.
class LiquidPills extends StatefulWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const LiquidPills(this.labels, this.index, this.onChanged, {super.key});
  @override
  State<LiquidPills> createState() => _LiquidPillsState();
}

class _LiquidPillsState extends State<LiquidPills> with SingleTickerProviderStateMixin {
  late final List<GlobalKey> _keys = [for (var i = 0; i < widget.labels.length; i++) GlobalKey()];
  final GlobalKey _rowKey = GlobalKey();
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750), value: 1);
  Rect? _from, _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(initial: true));
  }

  @override
  void didUpdateWidget(covariant LiquidPills old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Rect? _rectOf(int i) {
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final chip = _keys[i].currentContext?.findRenderObject() as RenderBox?;
    if (row == null || chip == null || !row.hasSize || !chip.hasSize) return null;
    final o = chip.localToGlobal(Offset.zero, ancestor: row);
    return o & chip.size;
  }

  void _measure({bool initial = false}) {
    if (!mounted) return;
    final r = _rectOf(widget.index);
    if (r == null) return;
    setState(() {
      _from = initial || _to == null ? r : _currentRect();
      _to = r;
    });
    if (initial || reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  Rect _currentRect() {
    final a = _from, b = _to;
    if (a == null || b == null) return b ?? a ?? Rect.zero;
    return _rectAt(a, b, _c.value);
  }

  Rect _rectAt(Rect a, Rect b, double t) {
    // Leading edge races ahead, trailing edge follows: the highlight stretches like liquid.
    final movingRight = b.center.dx >= a.center.dx;
    final fast = Curves.easeOutCubic.transform(t);
    final slow = Curves.easeInOutCubic.transform(((t - 0.12) / 0.88).clamp(0.0, 1.0));
    final left = movingRight ? a.left + (b.left - a.left) * slow : a.left + (b.left - a.left) * fast;
    final right = movingRight ? a.right + (b.right - a.right) * fast : a.right + (b.right - a.right) * slow;
    return Rect.fromLTRB(left, b.top, right, b.bottom);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border), boxShadow: C.shadow),
          child: Stack(children: [
            if (_to != null)
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final r = _from == null ? _to! : _rectAt(_from!, _to!, _c.value);
                  return Positioned(
                    left: r.left,
                    top: r.top,
                    width: r.width,
                    height: r.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E94F5), Color(0xFF0B5FC4)]),
                        boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                    ),
                  );
                },
              ),
            Row(key: _rowKey, mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < widget.labels.length; i++)
                Pressable(
                  onTap: () => widget.onChanged(i),
                  child: Container(
                    key: _keys[i],
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    color: Colors.transparent,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: i == widget.index ? Colors.white : C.muted),
                      child: Text(widget.labels[i]),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      );
}
