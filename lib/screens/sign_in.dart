import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../guide.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';

void _enter(BuildContext context) {
  GuideStore.pendingTour = true; // the welcome tour shows once, on the first visit
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Shell()), (r) => false);
}

/// Sign in, laid out like Claude's: the name at the top, a quiet animation in the middle, and the ways to continue at the bottom.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  void _email(BuildContext context) => showSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Continue with email'),
          const SizedBox(height: 14),
          const Field('Email', initial: 'demo@viewrec.com', keyboard: TextInputType.emailAddress),
          const Field('Password', initial: 'password'),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => showMsg(context, 'Reset link sent'), child: const Text('Forgot password?'))),
          const SizedBox(height: 6),
          AppButton('Sign in', onTap: () {
            Navigator.pop(context);
            _enter(context);
          }),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                  child: IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, color: C.text)),
                ),
              ),
              const SizedBox(height: 8),
              Text('ViewRec', key: const ValueKey('signin_name'), style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.8, color: C.text)).reveal(context, 0, 0.1),
              const SizedBox(height: 8),
              Text('Customer reviews, in their own voice.', style: TextStyle(fontSize: 15.5, color: C.muted, height: 1.4)).reveal(context, 1, 0.1),
              const Expanded(child: _Scene()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(children: [
                  _ProviderButton(
                    key: const ValueKey('signin_google'),
                    label: 'Continue with Google',
                    leading: const _GoogleG(),
                    background: C.dark ? C.surface : Colors.white,
                    foreground: C.text,
                    border: C.border,
                    onTap: () => _enter(context),
                  ),
                  const SizedBox(height: 12),
                  _ProviderButton(
                    key: const ValueKey('signin_apple'),
                    label: 'Continue with Apple',
                    leading: Icon(Icons.apple, size: 24, color: C.dark ? Colors.black : Colors.white),
                    background: C.dark ? Colors.white : Colors.black,
                    foreground: C.dark ? Colors.black : Colors.white,
                    onTap: () => _enter(context),
                  ),
                  const SizedBox(height: 12),
                  _ProviderButton(
                    key: const ValueKey('signin_email'),
                    label: 'Continue with email',
                    leading: Icon(Icons.mail_outline_rounded, size: 22, color: C.text),
                    background: Colors.transparent,
                    foreground: C.text,
                    border: C.border,
                    onTap: () => _email(context),
                  ),
                  const SizedBox(height: 16),
                  Text('By continuing you agree to our Terms and Privacy Policy.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted, height: 1.4)),
                ]),
              ).reveal(context, 2, 0.1),
            ]),
          ),
        ]),
      );
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final Color background, foreground;
  final Color? border;
  final VoidCallback onTap;
  const _ProviderButton({super.key, required this.label, required this.leading, required this.background, required this.foreground, this.border, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: Pressable(
            onTap: onTap,
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
                border: border == null ? null : Border.all(color: border!),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                leading,
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: foreground)),
              ]),
            ),
          ),
        ),
      );
}

/// The four colours of Google's G, drawn so no image file is needed.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const SweepGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)],
          stops: [0.0, 0.3, 0.55, 0.8, 1.0],
        ).createShader(r),
        blendMode: BlendMode.srcIn,
        child: const Text('G', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
      );
}

/// A calm scene: a play button with rings spreading from it, and testimonial cards drifting around it.
class _Scene extends StatefulWidget {
  const _Scene();
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  static const _cards = <(double, double, double, int, Color)>[
    // x (-1..1), y (-1..1), phase, stars, colour
    (-0.72, -0.35, 0.0, 5, Color(0xFF3E94F5)),
    (0.74, -0.55, 0.25, 5, Color(0xFF0FA386)),
    (-0.62, 0.55, 0.5, 4, Color(0xFFF2A100)),
    (0.68, 0.45, 0.75, 5, Color(0xFFFF6B5E)),
  ];

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final t = still ? 0.15 : c.value;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: CustomPaint(painter: _Rings(t, C.primary))),
            for (final k in _cards)
              Positioned(
                left: w / 2 + k.$1 * w * 0.36 - 52,
                top: h / 2 + k.$2 * h * 0.36 - 30 + math.sin((t + k.$3) * math.pi * 2) * 9,
                child: Transform.rotate(angle: math.sin((t + k.$3) * math.pi * 2) * 0.06, child: _MiniCard(stars: k.$4, color: k.$5)),
              ),
            Center(
              child: Transform.scale(
                scale: 1 + math.sin(t * math.pi * 2 * 2) * 0.035,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlue), boxShadow: C.glow),
                  child: const Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}

class _MiniCard extends StatelessWidget {
  final int stars;
  final Color color;
  const _MiniCard({required this.stars, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.dark ? Colors.white.withValues(alpha: 0.16) : Colors.white),
          boxShadow: C.dark ? null : [BoxShadow(color: C.primary.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 8, backgroundColor: color),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 5, decoration: BoxDecoration(color: C.muted.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3)))),
          ]),
          const SizedBox(height: 8),
          Row(children: [for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 13, color: i < stars ? const Color(0xFFFFC21A) : C.muted.withValues(alpha: 0.3))]),
        ]),
      );
}

class _Rings extends CustomPainter {
  final double t;
  final Color color;
  _Rings(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final max = math.min(size.width, size.height) * 0.5;
    for (var i = 0; i < 3; i++) {
      final p = (t * 2 + i / 3) % 1.0;
      canvas.drawCircle(c, 44 + p * (max - 44), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = color.withValues(alpha: (1 - p) * 0.28));
    }
  }

  @override
  bool shouldRepaint(_Rings o) => o.t != t || o.color != color;
}
