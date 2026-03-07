import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 70), () {
      if (!mounted) {
        return;
      }
      setState(() => _opacity = 1);
    });
    _timer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF142126), Color(0xFF050607), Color(0xFF050607)],
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          opacity: _opacity,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_rounded, color: Color(0xFF84E5DB), size: 62),
              SizedBox(height: 14),
              Text(
                'Parul University Navigator',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Campus-first live wayfinding',
                style: TextStyle(color: Color(0xFFA8B2B8), fontSize: 14),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
