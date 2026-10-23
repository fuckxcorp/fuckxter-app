import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'screens/home_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AppSession();
  runApp(FuckXterApp(session: session));
  unawaited(session.bootstrap());
}

class FuckXterApp extends StatelessWidget {
  const FuckXterApp({super.key, required this.session});

  final AppSession session;
  static final _light = _theme(Brightness.light);
  static final _dark = _theme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => MaterialApp(
        title: 'FuckXter',
        builder: (context, child) => AppTranslations(child: child!),
        locale: session.language == 'system' ? null : Locale(session.language),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        themeMode: session.themeMode,
        theme: _light,
        darkTheme: _dark,
        home: HomeScreen(session: session),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B7AA8),
        brightness: brightness,
        surface: dark ? Colors.black : Colors.white,
      ).copyWith(
        primary: dark ? const Color(0xFF7F9CC0) : const Color(0xFF5B7AA8),
        onSurface: dark ? const Color(0xFFC9CDD2) : const Color(0xFF3F4750),
        onSurfaceVariant: dark
            ? const Color(0xFF949AA3)
            : const Color(0xFF6C7480),
        outlineVariant: dark
            ? const Color(0xFF262626)
            : const Color(0xFFE3E6EA),
        surfaceContainerHighest: dark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F6F8),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark
            ? const Color(0xFFF2F4F6)
            : const Color(0xFF101215),
        foregroundColor: dark ? const Color(0xFF0B0C0E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215),
      foregroundColor: dark ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    scaffoldBackgroundColor: dark ? Colors.black : Colors.white,
    dividerColor: dark ? const Color(0xFF262626) : const Color(0xFFE3E6EA),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: dark ? const Color(0xFFC9CDD2) : const Color(0xFF3F4750),
      displayColor: dark ? const Color(0xFFF2F4F6) : const Color(0xFF1F2328),
    ),
  );
}
