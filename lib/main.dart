import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ZoneSyncApp());
}

class ZoneSyncApp extends StatelessWidget {
  const ZoneSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111F),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
