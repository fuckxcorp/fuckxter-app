import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const FuckXterApp());

class FuckXterApp extends StatefulWidget {
  const FuckXterApp({super.key});
  @override
  State<FuckXterApp> createState() => _FuckXterAppState();
}

class _FuckXterAppState extends State<FuckXterApp> {
  ThemeMode _mode = ThemeMode.system;
  void _toggleTheme() => setState(
      () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FuckXter',
        debugShowCheckedModeBanner: false,
        themeMode: _mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomeScreen(onToggleTheme: _toggleTheme),
      );
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B7AA8),
      brightness: brightness,
      surface: dark ? Colors.black : Colors.white);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Colors.black : Colors.white,
    dividerColor: dark ? const Color(0xFF262626) : const Color(0xFFE3E6EA),
    fontFamily: 'sans-serif',
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: dark ? const Color(0xFFC9CDD2) : const Color(0xFF3F4750),
        displayColor: dark ? const Color(0xFFF2F4F6) : const Color(0xFF1F2328)),
  );
}
