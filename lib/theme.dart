import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// App colors. Every color is a getter that reads [C.dark], so the whole UI
/// changes when the theme controller flips it and rebuilds the tree.
class C {
  static bool dark = true;

  static Color _p(Color d, Color l) => dark ? d : l;

  static Color get bg => _p(const Color(0xFF07070D), const Color(0xFFF4F4FA));
  static Color get surface => _p(const Color(0xFF11111B), const Color(0xFFFFFFFF));
  static Color get surface2 => _p(const Color(0xFF1A1A28), const Color(0xFFEEEEF7));
  static Color get border => _p(const Color(0x14FFFFFF), const Color(0xFFE6E6F1));
  static Color get text => _p(const Color(0xFFF5F5FA), const Color(0xFF12121C));
  static Color get muted => _p(const Color(0xFF8D8DA8), const Color(0xFF6C6C86));

  static const primary = Color(0xFF7C5CFF);
  static const primaryDeep = Color(0xFF5B3FE0);
  static Color get primarySoft => _p(const Color(0x297C5CFF), const Color(0x1F7C5CFF));
  static const rec = Color(0xFFFF3B5C);
  static Color get green => _p(const Color(0xFF2DD4A0), const Color(0xFF0F9F78));
  static Color get amber => _p(const Color(0xFFFBBF24), const Color(0xFFD97706));
  static Color get blue => _p(const Color(0xFF5AB0FF), const Color(0xFF2F8FE0));

  // Hero / highlight cards (Overview, Billing).
  static Color get heroA => _p(const Color(0xFF2E2370), const Color(0xFFEDE8FF));
  static Color get heroB => _p(const Color(0xFF16122F), const Color(0xFFF8F6FF));
  static Color get heroBorder => _p(const Color(0xFF43359A), const Color(0xFFD9D0FF));
  static Color get heroSub => _p(const Color(0xFFCBC3F0), const Color(0xFF4A4A68));
  static Color get accentText => _p(const Color(0xFFB8A6FF), const Color(0xFF5B3FD6));
  static Color get heroInset => _p(const Color(0x42000000), const Color(0xCCFFFFFF));
  static Color get heroPill => _p(const Color(0x1FFFFFFF), const Color(0x99FFFFFF));
  static Color get heroPillBorder => _p(const Color(0x3DFFFFFF), const Color(0xFFD9D0FF));

  /// Soft layered shadow for cards (light mode lifts them; dark mode relies on borders).
  static List<BoxShadow> get shadow => dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F1B1550), blurRadius: 28, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
        ];

  /// Glow under primary buttons and highlighted elements.
  static List<BoxShadow> get glow => [BoxShadow(color: primary.withValues(alpha: dark ? 0.38 : 0.30), blurRadius: 22, offset: const Offset(0, 8))];
}

const double rSm = 12, rMd = 18, rLg = 24;

/// Motion constants shared by every animation so the app feels consistent.
const kFast = Duration(milliseconds: 160);
const kMed = Duration(milliseconds: 320);
const kSlow = Duration(milliseconds: 650);
const kCurve = Curves.easeOutCubic;

ThemeData buildTheme({required bool dark}) {
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final text = base.textTheme.apply(fontFamily: 'Manrope', bodyColor: C.text, displayColor: C.text);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    textTheme: text,
    primaryTextTheme: text,
    colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: C.primary,
      surface: C.surface,
      onSurface: C.text,
      error: C.rec,
    ),
    // Opening a page slides it in from the side and fades, so moving forward and back feels directional.
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal, fillColor: C.bg),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: C.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.primarySoft,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? C.primary : C.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.primary : C.muted)),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : C.surface2),
      trackOutlineColor: WidgetStatePropertyAll(dark ? Colors.transparent : C.border),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? C.surface2 : const Color(0xFF14141F),
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
    ),
  );
}
