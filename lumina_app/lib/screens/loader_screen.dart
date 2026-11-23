import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/animated_orb.dart';

class LoaderScreen extends StatefulWidget {
  const LoaderScreen({super.key});

  @override
  State<LoaderScreen> createState() => _LoaderScreenState();
}

class _LoaderScreenState extends State<LoaderScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // After 2.2 seconds, transition to the Hero screen
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        context.read<LuminaAppState>().setScreen('hero');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;

    // Loading label style varies by theme
    final TextStyle labelStyle = isDark
        ? LuminaTypography.mono(
            fontSize: 14.0,
            fontWeight: FontWeight.w300,
            color: textColor.withValues(alpha: 0.60),
            letterSpacing: 0.14 * 14.0, // wide spacing
          )
        : LuminaTypography.serif(
            fontSize: 18.0,
            fontWeight: FontWeight.w300,
            color: textColor.withValues(alpha: 0.60),
            letterSpacing: 0.05 * 18.0,
          );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Orb
          AnimatedOrb(
            size: 108.0,
            isDark: isDark,
          ),
          
          const SizedBox(height: 28.0),
          
          // Loading message
          Text(
            'Waking up your world…',
            style: labelStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
