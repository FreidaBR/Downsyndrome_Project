import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/animated_orb.dart';
import '../widgets/custom_cursor.dart';

class HeroScreen extends StatelessWidget {
  const HeroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;
    final String themeLabel = isDark ? 'Candy Land' : 'Space Mode';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        constraints: const BoxConstraints(maxWidth: 520.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 0. Theme toggle
            Align(
              alignment: Alignment.centerRight,
              child: InteractiveCursorRegion(
                child: TextButton(
                  onPressed: () => state.toggleTheme(),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
                  ),
                  child: Text(
                    themeLabel,
                    style: LuminaTypography.sans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: isDark ? LuminaColors.darkText : LuminaColors.lightText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18.0),
            // 1. Orb
            AnimatedOrb(
              size: 108.0,
              isDark: isDark,
            ),
            
            const SizedBox(height: 30.0),
            
            // 2. Eyebrow Tag
            Text(
              'A FRIEND WHO LISTENS',
              style: LuminaTypography.sans(
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: mutedColor,
                letterSpacing: 0.24 * 11.0, // wide spacing
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 18.0),
            
            // 3. Meet Lumina Header (with Gradient Title)
            _GradientTitle(isDark: isDark),

            const SizedBox(height: 16.0),

            // 4. Description Paragraph
            Text(
              'Your magical companion curious, kind, and always here to explore the world with you.',
              style: LuminaTypography.sans(
                fontSize: 16.0,
                fontWeight: FontWeight.w300,
                color: mutedColor,
                height: 1.78,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 38.0),

            // 5. Begin Button
            InteractiveCursorRegion(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50.0),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                      blurRadius: 34.0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        context.read<LuminaAppState>().setScreen('onboarding');
                      },
                      splashColor: Colors.white24,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? LuminaColors.btnGradientDark
                              : LuminaColors.btnGradientLight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34.0, vertical: 14.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Begin the adventure',
                                style: LuminaTypography.sans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: 0.07 * 13.0,
                                ),
                              ),
                              const SizedBox(width: 9.0),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 14.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  final bool isDark;

  const _GradientTitle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final double titleSize = isDark ? 42.0 : 54.0;
    
    final TextStyle baseStyle = LuminaTypography.heroFont(
      isDark,
      fontSize: titleSize,
      fontWeight: FontWeight.w300,
      color: isDark ? LuminaColors.darkText : LuminaColors.lightText,
      letterSpacing: isDark ? 0.07 * titleSize : 0.0,
      height: 1.02,
    );

    // Light Theme: Meet [Lumina - italicized gradient]
    // Dark Theme: Meet [Lumina - normal gradient]
    final String textMeet = "Meet ";
    final String textLumina = "Lumina";

    final Gradient gradient = isDark
        ? LuminaColors.textGradDark
        : LuminaColors.textGradLight;

    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: textMeet),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return gradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  );
                },
                child: Text(
                  textLumina,
                  style: baseStyle.copyWith(
                    fontStyle: isDark ? FontStyle.normal : FontStyle.italic,
                    fontWeight: isDark ? FontWeight.w400 : FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
