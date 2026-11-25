import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'screens/welcome.dart';
import 'theme.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars so the soft background runs edge to edge.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await ThemeController.instance.load();
  runApp(const ViewRecApp());
}

class ViewRecApp extends StatefulWidget {
  const ViewRecApp({super.key});
  @override
  State<ViewRecApp> createState() => _ViewRecAppState();
}

class _ViewRecAppState extends State<ViewRecApp> {
  final theme = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    theme.addListener(_onTheme);
  }

  @override
  void dispose() {
    theme.removeListener(_onTheme);
    super.dispose();
  }

  /// Colors are read from [C] at build time, so after the palette flips every
  /// element is told to rebuild (state and navigation stack are kept).
  void _onTheme() {
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final dark = C.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
    final t = buildTheme(dark: dark);
    return MaterialApp(
      title: 'ViewRec',
      debugShowCheckedModeBanner: false,
      theme: t,
      darkTheme: t,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // The photo editor is built on material_ui and needs its text and dialog translations.
      localizationsDelegates: material_ui.GlobalMaterialLocalizations.delegates,
      // On the web, show a phone-width column so the preview looks like the real app.
      builder: kIsWeb
          ? (context, child) {
              final mq = MediaQuery.of(context);
              final w = mq.size.width > 480 ? 430.0 : mq.size.width;
              return ColoredBox(
                color: dark ? Colors.black : const Color(0xFFE4E4EF),
                child: Center(
                  child: SizedBox(
                    width: w,
                    child: MediaQuery(data: mq.copyWith(size: Size(w, mq.size.height)), child: ClipRect(child: child!)),
                  ),
                ),
              );
            }
          : null,
      home: const WelcomeScreen(),
    );
  }
}
