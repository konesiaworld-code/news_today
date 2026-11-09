import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const NewsTodayApp());
}

class NewsTodayApp extends StatelessWidget {
  const NewsTodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E5EFF);
    return MaterialApp(
      title: '뉴스투데이',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
