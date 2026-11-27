import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

/// A face the customer puts together to look like themselves, for when they would rather not show the camera.
class AvatarSpec {
  final int skin, hairStyle, hairColor, eyes, glasses, shirt;
  const AvatarSpec({this.skin = 1, this.hairStyle = 1, this.hairColor = 1, this.eyes = 0, this.glasses = 0, this.shirt = 0});

  static const skins = [Color(0xFFFFDFC4), Color(0xFFF0C09A), Color(0xFFD9A06F), Color(0xFFB47A4D), Color(0xFF8A5A38), Color(0xFF5C3A24)];
  static const hairColors = [Color(0xFF1B1B1F), Color(0xFF4A2E1B), Color(0xFF8A5A2B), Color(0xFFD9A441), Color(0xFFB5472F), Color(0xFF9AA0A6), Color(0xFFF2F2F2)];
  static const eyeColors = [Color(0xFF2B2B33), Color(0xFF3E6FB5), Color(0xFF4F8A4B), Color(0xFF7A4B2A)];
  static const shirts = [Color(0xFF3E94F5), Color(0xFF0FA386), Color(0xFFF2A100), Color(0xFFE5484D), Color(0xFF6D5DE7), Color(0xFF2B2B33)];
  static const hairStyleNames = ['Bald', 'Short', 'Long', 'Curly', 'Bun', 'Cap'];
  static const glassesNames = ['None', 'Round', 'Square', 'Sunglasses'];

  AvatarSpec copy({int? skin, int? hairStyle, int? hairColor, int? eyes, int? glasses, int? shirt}) => AvatarSpec(
        skin: skin ?? this.skin,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        eyes: eyes ?? this.eyes,
        glasses: glasses ?? this.glasses,
        shirt: shirt ?? this.shirt,
      );

  Map<String, int> toJson() => {'skin': skin, 'hairStyle': hairStyle, 'hairColor': hairColor, 'eyes': eyes, 'glasses': glasses, 'shirt': shirt};
  @override
  bool operator ==(Object o) => o is AvatarSpec && o.skin == skin && o.hairStyle == hairStyle && o.hairColor == hairColor && o.eyes == eyes && o.glasses == glasses && o.shirt == shirt;
  @override
  int get hashCode => Object.hash(skin, hairStyle, hairColor, eyes, glasses, shirt);
}

/// Draws the face. While [talking] the mouth opens and closes, so the avatar seems to speak along with the voice.
class FaceAvatar extends StatefulWidget {
  final AvatarSpec spec;
  final double size;
  final bool talking;
  final bool backdrop;
  const FaceAvatar({super.key, required this.spec, this.size = 120, this.talking = false, this.backdrop = true});
  @override
  State<FaceAvatar> createState() => _FaceAvatarState();
}

class _FaceAvatarState extends State<FaceAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.talking) c.repeat();
  }

  @override
  void didUpdateWidget(FaceAvatar o) {
    super.didUpdateWidget(o);
    if (widget.talking && !c.isAnimating) c.repeat();
    if (!widget.talking && c.isAnimating) c.stop();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FacePainter(widget.spec, widget.talking ? c.value : 0, widget.talking, widget.backdrop),
        ),
      );
}

class _FacePainter extends CustomPainter {
  final AvatarSpec s;
  final double t;
  final bool talking, backdrop;
  _FacePainter(this.s, this.t, this.talking, this.backdrop);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()..isAntiAlias = true;
    if (backdrop) {
      canvas.drawCircle(Offset(w / 2, w / 2), w / 2, p..color = AvatarSpec.shirts[s.shirt].withValues(alpha: 0.18));
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(w / 2, w / 2), radius: w / 2)));
    }
    final skin = AvatarSpec.skins[s.skin % AvatarSpec.skins.length];
    final hair = AvatarSpec.hairColors[s.hairColor % AvatarSpec.hairColors.length];
    // shoulders
    canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.12, w * 0.8, w * 0.76, w * 0.4), topLeft: Radius.circular(w * 0.3), topRight: Radius.circular(w * 0.3)), p..color = AvatarSpec.shirts[s.shirt % AvatarSpec.shirts.length]);
    // neck
    canvas.drawRect(Rect.fromLTWH(w * 0.42, w * 0.66, w * 0.16, w * 0.18), p..color = Color.lerp(skin, Colors.black, 0.08)!);
    final hs = s.hairStyle % AvatarSpec.hairStyleNames.length;
    // hair behind the head
    if (hs == 2) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, w * 0.2, w * 0.56, w * 0.58), Radius.circular(w * 0.22)), p..color = hair);
    if (hs == 3) {
      for (final o in [Offset(0.27, 0.33), Offset(0.73, 0.33), Offset(0.24, 0.47), Offset(0.76, 0.47)]) {
        canvas.drawCircle(Offset(w * o.dx, w * o.dy), w * 0.1, p..color = hair);
      }
    }
    if (hs == 4) canvas.drawCircle(Offset(w * 0.5, w * 0.13), w * 0.09, p..color = hair);
    // ears and head
    canvas.drawCircle(Offset(w * 0.28, w * 0.46), w * 0.045, p..color = skin);
    canvas.drawCircle(Offset(w * 0.72, w * 0.46), w * 0.045, p..color = skin);
    canvas.drawOval(Rect.fromLTWH(w * 0.28, w * 0.2, w * 0.44, w * 0.5), p..color = skin);
    // hair on top
    if (hs != 0) {
      final top = Path()
        ..moveTo(w * 0.27, w * 0.4)
        ..quadraticBezierTo(w * 0.26, w * 0.17, w * 0.5, w * 0.16)
        ..quadraticBezierTo(w * 0.74, w * 0.17, w * 0.73, w * 0.4)
        ..quadraticBezierTo(w * 0.66, w * 0.28, w * 0.5, w * 0.29)
        ..quadraticBezierTo(w * 0.34, w * 0.28, w * 0.27, w * 0.4)
        ..close();
      canvas.drawPath(top, p..color = hair);
      if (hs == 5) {
        canvas.drawArc(Rect.fromLTWH(w * 0.26, w * 0.13, w * 0.48, w * 0.3), math.pi, math.pi, true, p..color = AvatarSpec.shirts[(s.shirt + 3) % AvatarSpec.shirts.length]);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.5, w * 0.27, w * 0.28, w * 0.04), Radius.circular(w * 0.02)), p..color = AvatarSpec.shirts[(s.shirt + 3) % AvatarSpec.shirts.length]);
      }
    }
    // eyes: they blink now and then while talking
    final blink = talking && (t > 0.46 && t < 0.5 || t > 0.92 && t < 0.96);
    final eyeColor = AvatarSpec.eyeColors[s.eyes % AvatarSpec.eyeColors.length];
    for (final x in [0.41, 0.59]) {
      final c = Offset(w * x, w * 0.43);
      if (blink) {
        canvas.drawLine(Offset(c.dx - w * 0.03, c.dy), Offset(c.dx + w * 0.03, c.dy), p..color = const Color(0xFF2B2B33)..strokeWidth = w * 0.012..style = PaintingStyle.stroke);
        p.style = PaintingStyle.fill;
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.075, height: w * 0.06), p..color = Colors.white);
        canvas.drawCircle(c, w * 0.022, p..color = eyeColor);
      }
    }
    // brows
    final brow = Paint()..color = Color.lerp(hair, Colors.black, 0.2)!..strokeWidth = w * 0.014..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.37, w * 0.375), Offset(w * 0.45, w * 0.37), brow);
    canvas.drawLine(Offset(w * 0.55, w * 0.37), Offset(w * 0.63, w * 0.375), brow);
    // nose
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, w * 0.5), width: w * 0.04, height: w * 0.03), p..color = Color.lerp(skin, Colors.black, 0.12)!);
    // mouth
    final open = talking ? (0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 6))) : 0.0;
    final m = Offset(w * 0.5, w * 0.58);
    if (open > 0.2) {
      canvas.drawOval(Rect.fromCenter(center: m, width: w * 0.11, height: w * (0.012 + 0.05 * open)), p..color = const Color(0xFF7A2630));
    } else {
      final smile = Path()
        ..moveTo(m.dx - w * 0.05, m.dy - w * 0.005)
        ..quadraticBezierTo(m.dx, m.dy + w * 0.035, m.dx + w * 0.05, m.dy - w * 0.005);
      canvas.drawPath(smile, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.014..strokeCap = StrokeCap.round..color = const Color(0xFF7A2630));
    }
    // glasses
    if (s.glasses != 0) {
      final g = Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.012..color = const Color(0xFF2B2B33);
      final fill = Paint()..color = s.glasses == 3 ? const Color(0xCC15151B) : const Color(0x14FFFFFF);
      for (final x in [0.41, 0.59]) {
        final r = Rect.fromCenter(center: Offset(w * x, w * 0.43), width: w * 0.14, height: w * 0.1);
        final shape = s.glasses == 1 ? RRect.fromRectAndRadius(r, Radius.circular(w * 0.05)) : RRect.fromRectAndRadius(r, Radius.circular(w * 0.015));
        canvas.drawRRect(shape, fill);
        canvas.drawRRect(shape, g);
      }
      canvas.drawLine(Offset(w * 0.48, w * 0.42), Offset(w * 0.52, w * 0.42), g);
    }
    if (backdrop) canvas.restore();
  }

  @override
  bool shouldRepaint(_FacePainter o) => o.s != s || o.t != t || o.talking != talking;
}

/// Pick the look: skin, hair, eyes, glasses and top, with the face updating as you go.
class AvatarBuilder extends StatefulWidget {
  final AvatarSpec initial;
  final ValueChanged<AvatarSpec> onChanged;
  const AvatarBuilder({super.key, this.initial = const AvatarSpec(), required this.onChanged});
  @override
  State<AvatarBuilder> createState() => _AvatarBuilderState();
}

class _AvatarBuilderState extends State<AvatarBuilder> {
  late AvatarSpec spec = widget.initial;

  void _set(AvatarSpec s) {
    setState(() => spec = s);
    widget.onChanged(s);
  }

  Widget _dots(String label, List<Color> colors, int value, AvatarSpec Function(int) make) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < colors.length; i++)
              GestureDetector(
                key: ValueKey('$label$i'),
                onTap: () => _set(make(i)),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle, border: Border.all(color: value == i ? C.primary : C.border, width: value == i ? 3 : 1)),
                ),
              ),
          ]),
        ]),
      );

  Widget _chips(String label, List<String> names, int value, AvatarSpec Function(int) make) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < names.length; i++) AppChip(names[i], active: value == i, onTap: () => _set(make(i))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: FaceAvatar(spec: spec, size: 150)),
        const SizedBox(height: 18),
        _dots('Skin', AvatarSpec.skins, spec.skin, (i) => spec.copy(skin: i)),
        _chips('Hair', AvatarSpec.hairStyleNames, spec.hairStyle, (i) => spec.copy(hairStyle: i)),
        _dots('Hair colour', AvatarSpec.hairColors, spec.hairColor, (i) => spec.copy(hairColor: i)),
        _dots('Eyes', AvatarSpec.eyeColors, spec.eyes, (i) => spec.copy(eyes: i)),
        _chips('Glasses', AvatarSpec.glassesNames, spec.glasses, (i) => spec.copy(glasses: i)),
        _dots('Top', AvatarSpec.shirts, spec.shirt, (i) => spec.copy(shirt: i)),
      ]);
}
