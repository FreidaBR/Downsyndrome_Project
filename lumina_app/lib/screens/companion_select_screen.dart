import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_cursor.dart';

class CompanionSelectScreen extends StatelessWidget {
  const CompanionSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;
    final String themeLabel = isDark ? 'Candy Land' : 'Space Mode';

    // Define companion options matching the website
    final List<Companion> companions = [
      const Companion(
        name: 'Robot',
        trait: 'Helper',
        bgColors: [Color(0xFF818CF8), Color(0xFF312E81)],
        avatarType: 'robot',
      ),
      const Companion(
        name: 'Lumi',
        trait: 'Cat',
        bgColors: [Color(0xFFF9A8D4), Color(0xFFBE185D)],
        avatarType: 'cat',
      ),
      const Companion(
        name: 'Blaze',
        trait: 'Dog',
        bgColors: [Color(0xFFFCD34D), Color(0xFFB45309)],
        avatarType: 'dog',
      ),
    ];

    final String name = state.userName.isNotEmpty ? state.userName : 'friend';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Text(
              'Choose your companion',
              style: LuminaTypography.heroFont(
                isDark,
                fontSize: isDark ? 22.0 : 30.0,
                fontWeight: FontWeight.w300,
                color: textColor,
                letterSpacing: isDark ? 0.06 * 22.0 : 0.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5.0),
            
            // Subtitle
            Text(
              'Who do you want to explore with today, $name?',
              style: LuminaTypography.sans(
                fontSize: 13.0,
                color: mutedColor,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 10.0),
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
            const SizedBox(height: 24.0),

            // Companions Grid
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              alignment: WrapAlignment.center,
              children: companions.map((companion) {
                return _CompanionCard(
                  companion: companion,
                  isDark: isDark,
                  onTap: () {
                    context.read<LuminaAppState>().selectCompanion(companion);
                    context.read<LuminaAppState>().setScreen('chat');
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionCard extends StatefulWidget {
  final Companion companion;
  final bool isDark;
  final VoidCallback onTap;

  const _CompanionCard({
    required this.companion,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.companion;
    final isDark = widget.isDark;
    
    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;
    final Color activeBorder = isDark ? LuminaColors.darkA1 : LuminaColors.lightA1;

    // Outer shadow changes depending on hover and theme
    List<BoxShadow> shadows = [
      BoxShadow(
        color: isDark ? LuminaColors.darkShadow : LuminaColors.lightShadow,
        blurRadius: _isHovered ? 56.0 : 22.0,
        offset: Offset(0, _isHovered ? 28.0 : 8.0),
        spreadRadius: _isHovered ? -5.0 : 0.0,
      ),
    ];
    if (isDark && _isHovered) {
      shadows.add(
        BoxShadow(
          color: const Color(0xFF818CF8).withValues(alpha: 0.20),
          blurRadius: 40.0,
          spreadRadius: 2.0,
        ),
      );
    }

    return InteractiveCursorRegion(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOut,
            width: 122.0,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _isHovered ? -14.0 : 0.0, 0.0, 1.0)
              ..scaleByDouble(_isHovered ? 1.06 : 1.0, _isHovered ? 1.06 : 1.0, 1.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: _isHovered 
                    ? activeBorder 
                    : (isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB),
                width: 1.0,
              ),
              boxShadow: shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: GlassContainer(
                isDark: isDark,
                blurSigma: 20.0,
                borderRadius: BorderRadius.circular(24.0),
                padding: const EdgeInsets.only(top: 28.0, bottom: 22.0, left: 14.0, right: 14.0),
                child: Stack(
                  children: [
                    // Hover background glow gradient
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE879F9).withValues(alpha: 0.12),
                              const Color(0xFFA78BFA).withValues(alpha: 0.07),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    
                    // Main content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar Circle
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOut,
                          turns: _isHovered ? (7 / 360) : 0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOut,
                            scale: _isHovered ? 1.20 : 1.0,
                            child: Container(
                              width: 80.0,
                              height: 80.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: c.bgColors,
                                  center: const Alignment(-0.33, -0.33),
                                  radius: 0.7,
                                ),
                              ),
                              child: Center(
                                child: _buildAvatarIcon(c.avatarType),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12.0),
                        
                        // Companion Name
                        Text(
                          c.name == 'Robot' ? 'AI assistant' : c.name,
                          style: isDark
                              ? LuminaTypography.mono(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  letterSpacing: 0.05 * 10.0,
                                )
                              : LuminaTypography.heroFont(
                                  isDark,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 2.0),

                        // Companion Trait/Type
                        Text(
                          c.avatarType.toUpperCase(),
                          style: LuminaTypography.sans(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                            letterSpacing: 0.12 * 9.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarIcon(String type) {
    return CustomPaint(
      size: const Size(28.0, 28.0),
      painter: _AvatarPainter(type: type),
    );
  }
}

// ══════════════════════════════════════════════
// CUSTOM AVATAR PAINTER (ROBOT, CAT, DOG)
// ══════════════════════════════════════════════

class _AvatarPainter extends CustomPainter {
  final String type;

  _AvatarPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    if (type == 'robot') {
      // Draw Robot SVG
      // Rectangle: rect x="3" y="11" width="18" height="10" rx="2"
      final robotRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(3.0, 11.0, 18.0, 10.0),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(robotRect, paint);
      
      // Antenna circle: circle cx="12" cy="5" r="2"
      canvas.drawCircle(const Offset(12.0, 5.0), 2.0, paint);

      // Antenna line: path d="M12 7v4"
      canvas.drawLine(const Offset(12.0, 7.0), const Offset(12.0, 11.0), paint);

      // Eyes: M8 16h.01, M16 16h.01
      canvas.drawCircle(const Offset(8.0, 16.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(16.0, 16.0), 1.0, fillPaint);
    } else if (type == 'cat') {
      // Draw Cat SVG
      // Head/outline path: d="M12 21s-6-4.5-6-9a6 6 0 1 1 12 0c0 4.5-6 9-6 9Z"
      final path = Path()
        ..moveTo(12.0, 21.0)
        ..quadraticBezierTo(6.0, 16.5, 6.0, 12.0)
        ..arcToPoint(
          const Offset(18.0, 12.0),
          radius: const Radius.circular(6.0),
          largeArc: true,
        )
        ..quadraticBezierTo(18.0, 16.5, 12.0, 21.0)
        ..close();
      canvas.drawPath(path, paint);

      // Eyes: circle cx="9" cy="10" r="1", cx="15" cy="10" r="1"
      canvas.drawCircle(const Offset(9.0, 10.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(15.0, 10.0), 1.0, fillPaint);

      // Ears/Whiskers: M6 8l-3-3, M18 8l3-3
      canvas.drawLine(const Offset(6.0, 8.0), const Offset(3.0, 5.0), paint);
      canvas.drawLine(const Offset(18.0, 8.0), const Offset(21.0, 5.0), paint);
    } else {
      // Draw Dog SVG
      // Mouth flap: path d="M10 5.172v.328c0 1.105.895 2 2 2s2-.895 2-2v-.328"
      final path = Path()
        ..moveTo(10.0, 5.17)
        ..lineTo(10.0, 5.5)
        ..quadraticBezierTo(10.0, 7.5, 12.0, 7.5)
        ..quadraticBezierTo(14.0, 7.5, 14.0, 5.5)
        ..lineTo(14.0, 5.17);
      canvas.drawPath(path, paint);

      // Head circle (fallback visual base to make it look clean like the original)
      final dogHead = Rect.fromCircle(center: const Offset(12.0, 12.0), radius: 8.0);
      canvas.drawOval(dogHead, paint);

      // Eyes: circle cx="9" cy="13" r="1", cx="15" cy="13" r="1"
      canvas.drawCircle(const Offset(9.0, 12.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(15.0, 12.0), 1.0, fillPaint);

      // Nose: M12 16v.01
      canvas.drawCircle(const Offset(12.0, 14.5), 1.0, fillPaint);

      // Ears: M7 11.28l-1.4 1.4, M17 11.28l1.4-1.4
      canvas.drawLine(const Offset(7.0, 11.0), const Offset(4.0, 8.0), paint);
      canvas.drawLine(const Offset(17.0, 11.0), const Offset(20.0, 8.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
