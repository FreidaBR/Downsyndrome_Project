import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/canvas_background.dart';
import '../widgets/custom_cursor.dart';
import 'loader_screen.dart';
import 'hero_screen.dart';
import 'onboarding_screen.dart';
import 'companion_select_screen.dart';
import 'chat_screen.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    // Resolve the active screen widget based on app state
    Widget activeScreen;
    switch (state.currentScreen) {
      case 'loader':
        activeScreen = const LoaderScreen(key: ValueKey('loader'));
        break;
      case 'hero':
        activeScreen = const HeroScreen(key: ValueKey('hero'));
        break;
      case 'onboarding':
        activeScreen = const OnboardingScreen(key: ValueKey('onboarding'));
        break;
      case 'companion_select':
        activeScreen = const CompanionSelectScreen(key: ValueKey('companion_select'));
        break;
      case 'chat':
        activeScreen = const ChatScreen(key: ValueKey('chat'));
        break;
      default:
        activeScreen = const LoaderScreen(key: ValueKey('loader'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomCursor(
        isDark: isDark,
        child: Stack(
          children: [
            // 1. Live Animated Background
            Positioned.fill(
              child: CanvasBackground(themeMode: state.themeMode),
            ),
            
            // 2. Main screen viewport with fade transition
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: activeScreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
