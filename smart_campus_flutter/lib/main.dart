import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SmartCampusApp());
}

class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Campus Navigator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkMonochrome,
      home: const SplashScreen(),
    );
  }
}
