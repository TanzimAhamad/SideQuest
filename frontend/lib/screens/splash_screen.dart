
import 'package:flutter/material.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    openLogin();
  }

  Future<void> openLogin() async {
    await Future.delayed(const Duration(seconds: 10));//delayyyyy

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
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
            colors: [
              Color(0xFF111126),
              Color(0xFF33205E),
              Color(0xFF131327),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6)
                          .withValues(alpha: 0.35),
                      blurRadius: 45,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 62,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'SideQuest',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Less deciding. More doing.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB9B1D5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
