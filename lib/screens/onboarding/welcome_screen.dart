import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Welcome screen background image
          Image.asset('assets/welcome/welcome_screen.png', fit: BoxFit.cover),

          // Button overlay at bottom
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: SafeArea(
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onContinue();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B6F47), // Latte brown
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Let\'s Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Caveat',
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
