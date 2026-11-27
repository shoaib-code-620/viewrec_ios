import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// App colors. Every color is a getter that reads [C.dark], so the whole UI
/// changes when the theme controller flips it and rebuilds the tree.
///
/// The look is the "premium HD" design: a clear blue as the main colour, navy text, a very pale blue page with
/// soft teal, yellow and coral glows, and warm accents (coral, yellow, teal) for status and highlights.
class C {
  static bool dark = false;
  /// Special mode: the premium look. Airy and pastel in daylight, deep and glassy at night, with livelier backgrounds.
  static bool special = false;

  static Color _p(Color d, Color l) => dark ? d : l;

  static Color get bg => _p(const Color(0xFF06101F), const Color(0xFFF5F9FF));
  static Color get surface => _p(const Color(0xFF0E1B33), const Color(0xFFFFFFFF));
  static Color get surface2 => _p(const Color(0xFF16264A), const Color(0xFFEEF4FF));
  static Color get border => _p(const Color(0x1FFFFFFF), const Color(0xFFE1EAF8));
  static Color get text => _p(const Color(0xFFF2F7FF), const Color(0xFF0B1B3A));
  static Color get muted => _p(const Color(0xFF9DB0CF), const Color(0xFF5A6E92));

  /// The main colour. Gradients run from [primaryLight] to [primaryDeep].
  static const primary = Color(0xFF0B5FC4);
  static const primaryLight = Color(0xFF3E94F5);
  static const primaryDeep = Color(0xFF0847A0);
  static Color get primarySoft => _p(const Color(0x333E94F5), const Color(0x1A0B5FC4));
  static const rec = Color(0xFFE4513F);
  static Color get green => _p(const Color(0xFF1FC9A4), const Color(0xFF0FA386));
  static Color get amber => _p(const Color(0xFFFFC21A), const Color(0xFFD98F00));
  static Color get blue => _p(const Color(0xFF6DB0FF), const Color(0xFF3E94F5));
  static const coral = Color(0xFFFF6B5E);
  static const yellow = Color(0xFFFFC21A);
  static const teal = Color(0xFF1FC9A4);

  // The glossy button and highlight gradients of the design.
  static const gradBlue = [Color(0xFF3E94F5), Color(0xFF0B5FC4)];
  static const gradBlueDeep = [Color(0xFF3E94F5), Color(0xFF0B5FC4), Color(0xFF0847A0)];
  static const gradCoral = [Color(0xFFFF9D92), Color(0xFFFF6B5E), Color(0xFFE4513F)];
  static const gradYellow = [Color(0xFFFFE07A), Color(0xFFFFC21A), Color(0xFFF2A100)];
  static const gradTeal = [Color(0xFF5BE8C6), Color(0xFF1FC9A4), Color(0xFF0FA386)];

  // Hero / highlight cards (Overview, Billing).
  static Color get heroA => _p(const Color(0xFF123A78), const Color(0xFFE6F0FF));
  static Color get heroB => _p(const Color(0xFF0A1B3C), const Color(0xFFF4F9FF));
  static Color get heroBorder => _p(const Color(0xFF2A5AA8), const Color(0xFFCFE2FF));
  static Color get heroSub => _p(const Color(0xFFB9CEEE), const Color(0xFF41567A));
  static Color get accentText => _p(const Color(0xFF8CC3FF), const Color(0xFF0B5FC4));
  static Color get heroInset => _p(const Color(0x42000000), const Color(0xCCFFFFFF));
  static Color get heroPill => _p(const Color(0x1FFFFFFF), const Color(0x99FFFFFF));
  static Color get heroPillBorder => _p(const Color(0x3DFFFFFF), const Color(0xFFCFE2FF));

  /// Soft layered shadow for cards: a faint dark edge and a wide blue glow (dark mode relies on borders).
  static List<BoxShadow> get shadow => dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F0B1B3A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1A0B5FC4), blurRadius: 28, offset: Offset(0, 10)),
        ];

  /// Glow under primary buttons and highlighted elements.
  static List<BoxShadow> get glow => [BoxShadow(color: primary.withValues(alpha: dark ? 0.42 : 0.34), blurRadius: 18, offset: const Offset(0, 8))];
}

const double rSm = 14, rMd = 20, rLg = 28;

/// Motion constants shared by every animation so the app feels consistent.
const kFast = Duration(milliseconds: 160);
const kMed = Duration(milliseconds: 320);
const kSlow = Duration(milliseconds: 650);
const kCurve = Curves.easeOutCubic;

ThemeData buildTheme({required bool dark}) {
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final text = base.textTheme.apply(fontFamily: 'PlusJakartaSans', bodyColor: C.text, displayColor: C.text);
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
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans'),
    ),
  );
}
