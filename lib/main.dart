import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AppSession();
  await session.bootstrap();
  runApp(FuckXterApp(session: session));
}

class FuckXterApp extends StatelessWidget {
  const FuckXterApp({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => MaterialApp(
        title: 'FuckXter',
        debugShowCheckedModeBanner: false,
        themeMode: session.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomeScreen(session: session),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B7AA8),
    brightness: brightness,
    surface: dark ? Colors.black : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Colors.black : Colors.white,
    dividerColor: dark ? const Color(0xFF262626) : const Color(0xFFE3E6EA),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: dark ? const Color(0xFFC9CDD2) : const Color(0xFF3F4750),
          displayColor:
              dark ? const Color(0xFFF2F4F6) : const Color(0xFF1F2328),
        ),
  );
}
