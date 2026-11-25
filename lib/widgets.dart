import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'liquid_widgets.dart';
import 'motion.dart';
import 'theme.dart';

/// Scrollable page with the app's standard padding.
class AppPage extends StatelessWidget {
  final List<Widget> children;
  /// Fade and rise each block in one after another. Turn off for pages that stagger by themselves.
  final bool reveal;
  /// Side padding. Set to 0 for feeds that run edge to edge.
  final double hPad;
  const AppPage({super.key, required this.children, this.reveal = true, this.hPad = 18});
  @override
  Widget build(BuildContext context) {
    var n = 0;
    return Stack(children: [
      const Positioned.fill(child: LiquidBackdrop()),
      SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 120),
          children: [
            for (final c in children)
              (!reveal || c is SizedBox) ? c : c.reveal(context, (n++).clamp(0, 9), 0.05),
          ],
        ),
      ),
    ]);
  }
}

class H1 extends StatelessWidget {
  final String text;
  final double size;
  final List<InlineSpan>? tail;
  const H1(this.text, {super.key, this.size = 30, this.tail});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(text: text, children: tail),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.2, color: C.text),
      );
}

class H2 extends StatelessWidget {
  final String text;
  const H2(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3));
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;
  final int? maxLines;
  const Muted(this.text, {super.key, this.size = 15, this.align, this.maxLines});
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: TextStyle(fontSize: size, height: 1.45, color: C.muted));
}

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        // The design's glass card: soft white fill, white edge, blue-tinted shadow.
        gradient: borderColor == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: C.dark
                    ? [C.surface, C.surface]
                    : [Colors.white.withValues(alpha: 0.94), Colors.white.withValues(alpha: 0.78)],
              )
            : null,
        color: borderColor != null ? C.surface : null,
        borderRadius: BorderRadius.circular(rLg + 4),
        border: Border.all(color: borderColor ?? (C.dark ? C.border : Colors.white.withValues(alpha: 0.9)), width: borderWidth),
        boxShadow: C.dark
            ? C.shadow
            : [
                BoxShadow(color: const Color(0xFF0B1B3A).withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 2)),
                BoxShadow(color: const Color(0xFF0B5FC4).withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 14)),
              ],
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.985, child: card);
  }
}

/// The design's faint play-triangle pattern, drawn over blue feature panels.
class PlayPattern extends StatelessWidget {
  const PlayPattern({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _PlayPatternPainter()));
}

class _PlayPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (double y = 0; y < size.height + 44; y += 44) {
      for (double x = 0; x < size.width + 44; x += 44) {
        canvas.drawPath(Path()..moveTo(x + 14, y + 10)..lineTo(x + 14, y + 24)..lineTo(x + 26, y + 17)..close(), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glossy gradient icon tile from the design (coloured 3D chip with a white glyph).
class GlossIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool circle;
  const GlossIcon(this.icon, this.color, {super.key, this.size = 42, this.circle = false});
  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(color, Colors.white, 0.38)!;
    final bottom = Color.lerp(color, const Color(0xFF0B1B3A), 0.22)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.36),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, color, bottom], stops: const [0, 0.55, 1]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1),
      ),
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );
  }
}

enum BtnStyle { primary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BtnStyle style;
  final bool small;
  final bool loading;
  const AppButton(this.label, {super.key, this.onTap, this.icon, this.style = BtnStyle.primary, this.small = false, this.loading = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final fg = style == BtnStyle.ghost ? C.text : Colors.white;
    final radius = BorderRadius.circular(999);
    final deco = switch (style) {
      BtnStyle.primary => BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
          boxShadow: enabled ? [BoxShadow(color: C.primary.withValues(alpha: small ? 0.22 : 0.36), blurRadius: small ? 10 : 16, offset: Offset(0, small ? 4 : 7))] : null,
        ),
      BtnStyle.ghost => BoxDecoration(color: C.surface, border: Border.all(color: C.border), borderRadius: radius, boxShadow: C.shadow),
      BtnStyle.danger => BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A80), Color(0xFFE4513F)]),
          borderRadius: radius,
          boxShadow: enabled ? [BoxShadow(color: C.rec.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
    };
    final btn = Opacity(
      opacity: (onTap == null && !loading) ? 0.5 : 1,
      child: Pressable(
        onTap: enabled ? onTap : null,
        glow: style == BtnStyle.primary ? C.primary : (style == BtnStyle.danger ? C.rec : null),
        glowRadius: small ? 14 : 18,
        child: AnimatedContainer(
          duration: kMed,
          curve: kCurve,
          decoration: deco,
          padding: EdgeInsets.symmetric(vertical: small ? 11 : 16, horizontal: 22),
          child: AnimatedSwitcher(
            duration: kFast,
            child: loading
                ? SizedBox(key: const ValueKey('l'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(key: const ValueKey('t'), mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.max, children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                    Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 14 : 15.5, letterSpacing: 0.1))),
                  ]),
          ),
        ),
      ),
    );
    if (style == BtnStyle.primary && !small && enabled && !reduceMotion(context)) {
      return btn.animate(onPlay: (c) => c.repeat()).shimmer(duration: 2600.ms, delay: 2800.ms, color: Colors.white.withValues(alpha: 0.22), angle: 0.5);
    }
    return btn;
  }
}

class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const AppChip(this.label, {super.key, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: kMed,
            curve: kCurve,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: active ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
              color: active ? null : C.surface,
              border: Border.all(color: active ? Colors.white.withValues(alpha: 0.3) : C.border),
              borderRadius: BorderRadius.circular(999),
              boxShadow: active ? [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))] : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: kMed,
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : C.muted),
              child: Text(label),
            ),
          ),
        ),
      );
}

Color statusColor(String s) => switch (s) {
      'suggested' || 'pending' => C.amber,
      'approved' => C.primary,
      'invited' => C.blue,
      'recorded' || 'published' => C.green,
      _ => C.muted,
    };

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Pulse(
          active: status == 'pending' || status == 'suggested' || status == 'new',
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 5),
        PopOnChange(
          value: status,
          child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
        ),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? delta;
  const StatCard({super.key, required this.icon, required this.label, required this.value, this.delta});

  Widget _value() {
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.05);
    final i = int.tryParse(value);
    if (i != null) return CountUp(i, style: style);
    final d = double.tryParse(value);
    if (d != null) return CountUp(d, decimals: 1, style: style);
    return Text(value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlossIcon(icon, C.primary, size: 40),
          const SizedBox(height: 14),
          _value(),
          const SizedBox(height: 4),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.muted, height: 1.25)),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Text(delta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.green)),
            ),
          ],
        ]),
      );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});

  static const _pairs = [
    [Color(0xFF3E94F5), Color(0xFF0847A0)],
    [Color(0xFFFF8A6B), Color(0xFFFF6B5E)],
    [Color(0xFF3ED6B0), Color(0xFF0F9F78)],
    [Color(0xFF6DB0FF), Color(0xFF2F6FE0)],
    [Color(0xFFFFC857), Color(0xFFF2A100)],
    [Color(0xFF5BE8C6), Color(0xFF0FA386)],
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final pair = _pairs[name.codeUnits.fold<int>(0, (a, b) => a + b) % _pairs.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pair),
        boxShadow: size >= 40 ? [BoxShadow(color: pair[1].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))] : null,
      ),
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.36, color: Colors.white)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!, style: TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                Icon(Icons.chevron_right_rounded, size: 18, color: C.primary),
              ]),
            ),
        ]),
      );
}

class BackHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const BackHeader(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.border), boxShadow: C.shadow),
              child: Icon(Icons.chevron_left_rounded, size: 24, color: C.text),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.7))),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
      );
}

class VideoThumb extends StatelessWidget {
  final Color hue;
  final String? duration;
  final double height;
  const VideoThumb({super.key, required this.hue, this.duration, this.height = 150});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(rMd + 2),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hue, Color.lerp(hue, Colors.black, 0.6)!])),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
              child: const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
            ),
            if (duration != null && duration!.isNotEmpty)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(9)),
                  child: Text(duration!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ]),
        ),
      );
}

void showMsg(BuildContext context, String m) {
  final bottom = MediaQuery.of(context).padding.bottom;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(18, 0, 18, 104 + bottom),
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: const Duration(milliseconds: 2600),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.dark ? const Color(0xFF23233A) : const Color(0xFF0E1B33),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF1FC9A4)),
          const SizedBox(width: 12),
          Expanded(child: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'PlusJakartaSans'))),
        ]),
      ),
    ));
}

/// Tappable row: icon, title, optional subtitle, optional trailing widget.
class Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool divider;
  const Tile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.divider = true,
  });
  @override
  Widget build(BuildContext context) {
    final col = iconColor ?? C.primary;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: C.border)) : null),
        child: Row(children: [
          GlossIcon(icon, col),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (subtitle != null) ...[const SizedBox(height: 2), Muted(subtitle!, size: 12.5)],
            ]),
          ),
          if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right_rounded, size: 22, color: C.muted),
        ]),
      ),
    );
  }
}

/// Row with a switch, used in settings and automation pages.
class SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchTile(this.title, this.value, this.onChanged, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (subtitle != null) ...[const SizedBox(height: 2), Muted(subtitle!, size: 12.5)],
            ]),
          ),
          LiquidSwitch(value: value, onChanged: onChanged),
        ]),
      );
}

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color = C.primary});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: C.dark ? 0.14 : 0.1),
          borderRadius: BorderRadius.circular(rMd),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlossIcon(icon, color, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 1), child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500)))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const EmptyState(this.icon, this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          _Floating(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(alignment: Alignment.center, children: [
                if (!reduceMotion(context))
                  Container(width: 84, height: 84, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.primary.withValues(alpha: 0.35), width: 2)))
                      .animate(onPlay: (c) => c.repeat())
                      .scale(begin: const Offset(1, 1), end: const Offset(1.45, 1.45), duration: 2200.ms, curve: Curves.easeOut)
                      .fadeOut(duration: 2200.ms, curve: Curves.easeOut),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.primarySoft, border: Border.all(color: C.primary.withValues(alpha: 0.2))),
                  child: Icon(icon, size: 36, color: C.primary),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Muted(body, size: 13.5, align: TextAlign.center),
        ]),
      );
}

/// Labelled text field in the app's style.
class Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final int lines;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final String? initial;
  const Field(this.label, {super.key, this.hint, this.controller, this.lines = 1, this.keyboard, this.onChanged, this.initial});
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: c));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initial : null,
          minLines: lines,
          maxLines: lines,
          keyboardType: keyboard,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: C.muted),
            filled: true,
            fillColor: C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: b(C.border),
            enabledBorder: b(C.border),
            focusedBorder: b(C.primary),
          ),
        ),
      ]),
    );
  }
}

Future<void> showSheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 42, height: 5, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: C.border.withValues(alpha: 1), borderRadius: BorderRadius.circular(3)))),
              child,
            ]),
          ),
        ),
      ),
    );

/// Standard scaffold for pushed sub-pages.
class SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const SubPage(this.title, {super.key, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: AppPage(children: [BackHeader(title, trailing: trailing), ...children]));
}

/// Row of small tab pills used inside pages.
class Pills extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const Pills(this.labels, this.index, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: LiquidPills(labels, index, onChanged));
}

class Stars extends StatelessWidget {
  final int n;
  const Stars(this.n, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++) Icon(i <= n ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: C.amber),
      ]);
}


/// Gently drifts up and down. Used on empty-state icons so a quiet screen still feels alive.
class _Floating extends StatelessWidget {
  final Widget child;
  const _Floating({required this.child});
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return child
        .animate()
        .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 520.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 380.ms)
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -4, end: 4, duration: 2400.ms, curve: Curves.easeInOut);
  }
}

/// A soft breathing glow for status dots that need attention.
class _Pulse extends StatelessWidget {
  final bool active;
  final Widget child;
  const _Pulse({required this.active, required this.child});
  @override
  Widget build(BuildContext context) {
    if (!active || reduceMotion(context)) return child;
    return child.animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.35, 1.35), duration: 900.ms, curve: Curves.easeInOut).fade(begin: 0.55, end: 1, duration: 900.ms);
  }
}

/// A short, centred confirmation: a circle pops in and a tick draws itself, then it fades away.
void showSuccess(BuildContext context, String text, {bool confetti = true}) {
  if (confetti) showConfetti(context);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    showMsg(context, text);
    return;
  }
  HapticFeedback.mediumImpact();
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _SuccessToast(text: text, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _SuccessToast extends StatefulWidget {
  final String text;
  final VoidCallback onDone;
  const _SuccessToast({required this.text, required this.onDone});
  @override
  State<_SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<_SuccessToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final pop = Curves.easeOutBack.transform((t / 0.22).clamp(0.0, 1.0));
            final tick = Curves.easeOutCubic.transform(((t - 0.12) / 0.3).clamp(0.0, 1.0));
            final fade = t > 0.8 ? 1 - (t - 0.8) / 0.2 : 1.0;
            return Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Center(
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * pop,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                      decoration: BoxDecoration(color: C.dark ? C.surface2 : const Color(0xF2171722), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12))]),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 56, height: 56, child: CustomPaint(painter: _TickPainter(tick, C.green))),
                        const SizedBox(height: 12),
                        Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _TickPainter extends CustomPainter {
  final double t;
  final Color color;
  _TickPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28);
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 2, ring);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.36);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), p);
    }
  }

  @override
  bool shouldRepaint(_TickPainter o) => o.t != t;
}


// ---------------------------------------------------------------------------
// Drag and drop
// ---------------------------------------------------------------------------

/// One place a dragged card can be dropped, e.g. a status.
class DropZone {
  final String id, label;
  final Color color;
  final IconData icon;
  const DropZone(this.id, this.label, this.color, this.icon);
}

/// Long-press a card, lift it, and drop it on a [DropZoneBar]. Tapping still works as before.
class DragCard<T extends Object> extends StatelessWidget {
  final T data;
  final Widget child;
  final VoidCallback onStart, onEnd;
  const DragCard({super.key, required this.data, required this.child, required this.onStart, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 44;
    return LongPressDraggable<T>(
      data: data,
      delay: const Duration(milliseconds: 260),
      hapticFeedbackOnStart: true,
      maxSimultaneousDrags: 1,
      onDragStarted: onStart,
      onDragEnd: (_) => onEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: w,
          child: Transform.rotate(
            angle: 0.015,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(rLg), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 30, offset: Offset(0, 14))]),
              child: Opacity(opacity: 0.97, child: child),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: child),
      child: child,
    );
  }
}

/// Drop targets that slide down from the top while a card is being dragged. Dropping on one calls [onDrop].
class DropZoneBar<T extends Object> extends StatelessWidget {
  final bool show;
  final List<DropZone> zones;
  final void Function(T item, String zoneId) onDrop;
  final bool Function(T item, String zoneId)? canDrop;
  const DropZoneBar({super.key, required this.show, required this.zones, required this.onDrop, this.canDrop});

  @override
  Widget build(BuildContext context) {
    final slow = reduceMotion(context);
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedSlide(
        offset: show ? Offset.zero : const Offset(0, -1.4),
        duration: slow ? Duration.zero : const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: slow ? Duration.zero : const Duration(milliseconds: 220),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: C.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: C.border),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Row(children: [
              for (var i = 0; i < zones.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _zone(context, zones[i])),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _zone(BuildContext context, DropZone z) => DragTarget<T>(
        onWillAcceptWithDetails: (d) => canDrop?.call(d.data, z.id) ?? true,
        onAcceptWithDetails: (d) {
          HapticFeedback.mediumImpact();
          onDrop(d.data, z.id);
        },
        builder: (context, candidate, rejected) {
          final hot = candidate.isNotEmpty;
          final blocked = rejected.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scale(hot ? 1.06 : 1.0),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: hot ? z.color : z.color.withValues(alpha: blocked ? 0.05 : 0.13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: z.color.withValues(alpha: hot ? 1 : 0.35), width: hot ? 2 : 1),
              boxShadow: hot ? [BoxShadow(color: z.color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 5))] : null,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(z.icon, size: 20, color: hot ? Colors.white : z.color),
              const SizedBox(height: 3),
              Text(z.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: hot ? Colors.white : z.color)),
            ]),
          );
        },
      );
}


/// The ViewRec mark: a bookmark with a yellow play button. Drawn in code so it stays sharp at any size.
class BrandMark extends StatelessWidget {
  final double size;
  final Color? bookmark;
  const BrandMark({super.key, this.size = 40, this.bookmark});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _MarkPainter(bookmark ?? C.primary)));
}

class _MarkPainter extends CustomPainter {
  final Color bookmark;
  _MarkPainter(this.bookmark);
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    Offset p(double x, double y) => Offset(x * k, y * k);
    final book = Path()
      ..moveTo(p(17, 8).dx, p(17, 8).dy)
      ..lineTo(p(47, 8).dx, p(47, 8).dy)
      ..lineTo(p(47, 57).dx, p(47, 57).dy)
      ..lineTo(p(32, 44).dx, p(32, 44).dy)
      ..lineTo(p(17, 57).dx, p(17, 57).dy)
      ..close();
    final fill = Paint()..color = bookmark;
    final edge = Paint()
      ..color = bookmark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * k
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(book, fill);
    canvas.drawPath(book, edge);
    canvas.drawCircle(p(32, 23), 10.5 * k, Paint()..color = const Color(0xFFFFC21A));
    final tri = Path()
      ..moveTo(p(29.2, 18.2).dx, p(29.2, 18.2).dy)
      ..lineTo(p(29.2, 27.8).dx, p(29.2, 27.8).dy)
      ..lineTo(p(37.2, 23).dx, p(37.2, 23).dy)
      ..close();
    canvas.drawPath(tri, Paint()..color = bookmark);
    canvas.drawPath(
        tri,
        Paint()
          ..color = bookmark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * k
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.bookmark != bookmark;
}

/// The design's pricing "ticket": a rounded card with a notch on each side at the dashed divider.
/// [blue] gives the featured style (blue gradient with the play pattern).
class TicketCard extends StatefulWidget {
  final Widget top;
  final Widget bottom;
  final bool blue;
  const TicketCard({super.key, required this.top, required this.bottom, this.blue = false});
  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  final _topKey = GlobalKey();
  double? _notchY;

  void _measure() {
    final box = _topKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && mounted && _notchY != box.size.height) setState(() => _notchY = box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return CustomPaint(
      painter: _TicketPainter(_notchY, widget.blue, C.dark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KeyedSubtree(key: _topKey, child: Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 20), child: widget.top)),
        Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 22), child: widget.bottom),
      ]),
    );
  }
}

class _TicketPainter extends CustomPainter {
  final double? notchY;
  final bool blue, dark;
  _TicketPainter(this.notchY, this.blue, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(32)));
    if (notchY != null) {
      final holes = Path()
        ..addOval(Rect.fromCircle(center: Offset(0, notchY!), radius: 11))
        ..addOval(Rect.fromCircle(center: Offset(size.width, notchY!), radius: 11));
      path = Path.combine(PathOperation.difference, path, holes);
    }
    canvas.drawShadow(path, blue ? C.primary : const Color(0xFF0B5FC4), blue ? 26 : 10, true);
    final rect = Offset.zero & size;
    final paint = Paint();
    if (blue) {
      paint.shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlueDeep, stops: [0, 0.55, 1]).createShader(rect);
    } else {
      paint.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: dark ? [C.surface, C.surface] : const [Colors.white, Color(0xFFF4F8FF)]).createShader(rect);
    }
    canvas.drawPath(path, paint);
    if (blue) {
      canvas.save();
      canvas.clipPath(path);
      final p = Paint()..color = Colors.white.withValues(alpha: 0.08);
      for (double y = 0; y < size.height + 44; y += 44) {
        for (double x = 0; x < size.width + 44; x += 44) {
          canvas.drawPath(Path()..moveTo(x + 14, y + 10)..lineTo(x + 14, y + 24)..lineTo(x + 26, y + 17)..close(), p);
        }
      }
      canvas.restore();
    }
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = blue ? Colors.white.withValues(alpha: 0.3) : (dark ? C.border : Colors.white));
    if (notchY != null) {
      final dash = Paint()..color = (blue ? Colors.white : C.muted).withValues(alpha: 0.45)..strokeWidth = 1.2;
      for (double x = 16; x < size.width - 16; x += 7) {
        canvas.drawLine(Offset(x, notchY!), Offset(x + 3.5, notchY!), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter o) => o.notchY != notchY || o.blue != blue || o.dark != dark;
}
