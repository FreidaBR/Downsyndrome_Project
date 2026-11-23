import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LuminaThemeMode { light, dark }

class LuminaColors {
  // ══════════════════════════════════════════════
  // LIGHT MODE (Candy Land)
  // ══════════════════════════════════════════════
  static const Color lightText = Color(0xFF2D0A3F);
  static const Color lightMuted = Color(0xFFA070C0);
  static const Color lightFaint = Color(0xFFD4A8E8);
  static const Color lightSurface = Color(0x7BFFFFFF); // rgba(255, 255, 255, 0.48)
  static const Color lightSurfaceB = Color(0xD1FFFFFF); // rgba(255, 255, 255, 0.82)
  static const Color lightShadow = Color(0x1F8C3CC8); // rgba(140, 60, 200, 0.12)
  
  static const Color lightA1 = Color(0xFFE879F9);
  static const Color lightA2 = Color(0xFFA78BFA);
  static const Color lightA3 = Color(0xFFF472B6);
  static const Color green = Color(0xFF34D399);

  static const Color lightBubbleL1 = Color(0xFFF0ABFC);
  static const Color lightBubbleL2 = Color(0xFFC4B5FD);
  static const Color lightBubbleU1 = Color(0xFF6EE7B7);
  static const Color lightBubbleU2 = Color(0xFF7DD3FC);

  static const Color lightInBg = Color(0x8CFFFFFF); // rgba(255, 255, 255, 0.55)
  static const Color lightInBorder = Color(0x38E879F9); // rgba(232, 121, 249, 0.22)
  static const Color lightBtnSh = Color(0x66E879F9); // rgba(232, 121, 249, 0.4)
  static const Color lightCursor = Color(0xFFE879F9);

  // ══════════════════════════════════════════════
  // DARK MODE (Space Mode)
  // ══════════════════════════════════════════════
  static const Color darkText = Color(0xFFDDD6FE);
  static const Color darkMuted = Color(0xFF4F4690);
  static const Color darkFaint = Color(0xFF312E81);
  static const Color darkSurface = Color(0x9406041C); // rgba(6, 4, 28, 0.58)
  static const Color darkSurfaceB = Color(0x2E6366F1); // rgba(99, 102, 241, 0.18)
  static const Color darkShadow = Color(0x9900001E); // rgba(0, 0, 30, 0.6)

  static const Color darkA1 = Color(0xFF818CF8);
  static const Color darkA2 = Color(0xFF34D399);
  static const Color darkA3 = Color(0xFFF472B6);

  static const Color darkBubbleL1 = Color(0xFF1E1B4B);
  static const Color darkBubbleL2 = Color(0xFF312E81);
  static const Color darkBubbleU1 = Color(0xFF064E3B);
  static const Color darkBubbleU2 = Color(0xFF0C4A6E);

  static const Color darkInBg = Color(0x8C06041C); // rgba(6, 4, 28, 0.55)
  static const Color darkInBorder = Color(0x38818CF8); // rgba(129, 140, 248, 0.22)
  static const Color darkBtnSh = Color(0x61818CF8); // rgba(129, 140, 248, 0.38)
  static const Color darkCursor = Color(0xFF818CF8);

  // Helper gradients
  static const LinearGradient btnGradientLight = LinearGradient(
    colors: [lightA1, lightA2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient btnGradientDark = LinearGradient(
    colors: [darkA1, darkA2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient textGradLight = LinearGradient(
    colors: [Color(0xFFE879F9), Color(0xFFA78BFA), Color(0xFF7DD3FC)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient textGradDark = LinearGradient(
    colors: [darkA1, darkA2],
  );

  static const LinearGradient bubbleAILight = LinearGradient(
    colors: [lightBubbleL1, lightBubbleL2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleAIDark = LinearGradient(
    colors: [darkBubbleL1, darkBubbleL2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleUserLight = LinearGradient(
    colors: [lightBubbleU1, lightBubbleU2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleUserDark = LinearGradient(
    colors: [darkBubbleU1, darkBubbleU2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class LuminaTypography {
  // Sans-serif font family - Jost
  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jost(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Serif font family - Cormorant Garamond
  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }

  // Monospace font family - Orbitron
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Theme-sensitive Hero font selection
  static TextStyle heroFont(bool isDark, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    if (isDark) {
      return mono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    } else {
      return serif(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
      );
    }
  }
}
