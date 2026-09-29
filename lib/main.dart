import 'package:flutter/material.dart';

import 'models/account.dart';
import 'screens/home_screen.dart';
import 'services/fuckxter_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = await FuckXterApi.create();
  runApp(FuckXterApp(api: api));
}

class FuckXterApp extends StatefulWidget {
  const FuckXterApp({super.key, required this.api});

  final FuckXterApi api;

  @override
  State<FuckXterApp> createState() => _FuckXterAppState();
}

class _FuckXterAppState extends State<FuckXterApp> {
  ThemeMode _mode = ThemeMode.system;
  Account? _account;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      _account = await widget.api.me();
    } catch (_) {
      _account = null;
    }
    if (mounted) setState(() => _ready = true);
  }

  void _toggleTheme() => setState(
      () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FuckXter',
        debugShowCheckedModeBanner: false,
        themeMode: _mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: _ready
            ? HomeScreen(
                api: widget.api,
                account: _account,
                onAccountChanged: (value) => setState(() => _account = value),
                onToggleTheme: _toggleTheme,
              )
            : const Scaffold(
                body: Center(child: CircularProgressIndicator(strokeWidth: 2))),
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
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: dark ? const Color(0xFFC9CDD2) : const Color(0xFF3F4750),
        displayColor: dark ? const Color(0xFFF2F4F6) : const Color(0xFF1F2328)),
  );
}
