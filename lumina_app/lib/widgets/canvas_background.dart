import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class CanvasBackground extends StatefulWidget {
  final LuminaThemeMode themeMode;

  const CanvasBackground({super.key, required this.themeMode});

  @override
  State<CanvasBackground> createState() => _CanvasBackgroundState();
}

class _CanvasBackgroundState extends State<CanvasBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // State lists
  List<_CandyParticle> _candyParticles = [];
  List<_Cloud> _clouds = [];
  List<_SpaceParticle> _spaceParticles = [];
  List<_ShootingStar> _shootingStars = [];
  
  double _lastTime = 0.0;
  final math.Random _rand = math.Random();
  double _time = 0.0;

  // Screen size tracking to trigger re-initialization on resize
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(_updateAnimation)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAnimation() {
    if (!mounted) return;
    
    final double elapsed = _controller.value * 60.0; // scale to a running time
    double dt = elapsed - _lastTime;
    if (dt < 0) dt += 60.0; // Wrap around
    _lastTime = elapsed;
    
    // Add small time step
    _time += 0.016;
    
    setState(() {
      if (widget.themeMode == LuminaThemeMode.light) {
        _updateLightBackground(dt);
      } else {
        _updateDarkBackground(dt);
      }
    });
  }

  void _initBackgrounds(Size size) {
    _lastSize = size;
    
    // 1. Candy Land particles
    _candyParticles = List.generate(55, (index) {
      return _CandyParticle.random(size, _rand);
    });

    // 2. Clouds
    final List<Color> tints = [
      const Color(0xB8FFFFFF), // rgba(255,255,255,0.72)
      const Color(0xA5FFE4F5), // rgba(255,228,245,0.65)
      const Color(0x99DCE6FF), // rgba(220,240,255,0.6)
      const Color(0xADF5F5FF), // rgba(245,245,255,0.68)
    ];
    _clouds = List.generate(5, (index) {
      return _Cloud.random(size, tints[index % tints.length], _rand);
    });

    // 3. Space particles
    _spaceParticles = List.generate(200, (index) {
      bool isStar = index < 170;
      return _SpaceParticle.random(size, isStar, _rand);
    });

    _shootingStars = [];
  }

  void _updateLightBackground(double dt) {
    if (_lastSize == Size.zero) return;
    
    // Update Clouds
    for (var cloud in _clouds) {
      cloud.x += cloud.speed * 2.0;
      if (cloud.x - cloud.w > _lastSize.width) {
        cloud.x = -cloud.w - 100;
        cloud.y = 60 + _rand.nextDouble() * (_lastSize.height * 0.35);
      }
    }

    // Update Candy Particles
    for (var p in _candyParticles) {
      p.x += p.vx + math.sin(p.phase + _time * 0.5) * 0.15;
      p.y += p.vy;
      p.rot += p.rotV;
      
      // Reset if off screen top
      if (p.y < -20) {
        p.y = _lastSize.height + 20;
        p.x = _rand.nextDouble() * _lastSize.width;
      }
    }
  }

  void _updateDarkBackground(double dt) {
    if (_lastSize == Size.zero) return;

    // Periodically spawn shooting stars
    if (_rand.nextDouble() < 0.005 && _shootingStars.length < 3) {
      _shootingStars.add(_ShootingStar.random(_lastSize, _rand));
    }

    // Update shooting stars
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      var s = _shootingStars[i];
      s.x += math.cos(s.angle) * s.speed;
      s.y += math.sin(s.angle) * s.speed;
      s.life -= s.decay;
      if (s.life <= 0) {
        _shootingStars.removeAt(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Reinitialize if size changes
        if (size != _lastSize && size.width > 0 && size.height > 0) {
          _initBackgrounds(size);
        }

        return CustomPaint(
          size: size,
          painter: _BackgroundPainter(
            themeMode: widget.themeMode,
            time: _time,
            candyParticles: _candyParticles,
            clouds: _clouds,
            spaceParticles: _spaceParticles,
            shootingStars: _shootingStars,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
// DATA STRUCTURES
// ══════════════════════════════════════════════

class _CandyParticle {
  double x;
  double y;
  double size;
  Color color;
  String shape; // 'circle', 'star', 'diamond'
  double vx;
  double vy;
  double phase;
  double alpha;
  double rot;
  double rotV;

  _CandyParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.shape,
    required this.vx,
    required this.vy,
    required this.phase,
    required this.alpha,
    required this.rot,
    required this.rotV,
  });

  factory _CandyParticle.random(Size size, math.Random rand) {
    final shapes = ['circle', 'star', 'diamond'];
    final colors = [
      const Color(0xFFF9A8D4),
      const Color(0xFFC4B5FD),
      const Color(0xFF86EFAC),
      const Color(0xFFFCD34D),
      const Color(0xFF7DD3FC),
      const Color(0xFFFBCFE8),
      const Color(0xFFDDD6FE)
    ];
    return _CandyParticle(
      x: rand.nextDouble() * size.width,
      y: rand.nextDouble() * size.height,
      size: 3.0 + rand.nextDouble() * 9.0,
      color: colors[rand.nextInt(colors.length)],
      shape: shapes[rand.nextInt(shapes.length)],
      vx: (rand.nextDouble() - 0.5) * 0.3,
      vy: -0.12 - rand.nextDouble() * 0.25,
      phase: rand.nextDouble() * math.pi * 2,
      alpha: 0.25 + rand.nextDouble() * 0.5,
      rot: rand.nextDouble() * math.pi * 2,
      rotV: (rand.nextDouble() - 0.5) * 0.012,
    );
  }
}

class _Cloud {
  double x;
  double y;
  double w;
  double h;
  double speed;
  Color tint;
  double alpha;

  _Cloud({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.speed,
    required this.tint,
    required this.alpha,
  });

  factory _Cloud.random(Size size, Color tint, math.Random rand) {
    return _Cloud(
      x: rand.nextDouble() * size.width,
      y: 60.0 + rand.nextDouble() * (size.height * 0.35),
      w: 160.0 + rand.nextDouble() * 200.0,
      h: 55.0 + rand.nextDouble() * 45.0,
      speed: 0.18 + rand.nextDouble() * 0.22,
      tint: tint,
      alpha: 0.6 + rand.nextDouble() * 0.3,
    );
  }
}

class _SpaceParticle {
  double x;
  double y;
  double size;
  double alpha;
  double phase;
  double speed;
  bool isStar;
  Color color;

  _SpaceParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.speed,
    required this.isStar,
    required this.color,
  });

  factory _SpaceParticle.random(Size size, bool isStar, math.Random rand) {
    final colors = [const Color(0xFFC4B5FD), const Color(0xFF93C5FD), const Color(0xFF6EE7B7)];
    return _SpaceParticle(
      x: rand.nextDouble() * size.width,
      y: rand.nextDouble() * size.height,
      size: isStar ? 0.5 + rand.nextDouble() * 2.2 : 2.0 + rand.nextDouble() * 4.0,
      alpha: isStar ? 0.15 + rand.nextDouble() * 0.85 : 0.5 + rand.nextDouble() * 0.5,
      phase: rand.nextDouble() * math.pi * 2,
      speed: isStar ? 1.4 + rand.nextDouble() * 3.5 : 0.8 + rand.nextDouble() * 1.5,
      isStar: isStar,
      color: isStar ? Colors.white : colors[rand.nextInt(colors.length)],
    );
  }
}

class _ShootingStar {
  double x;
  double y;
  double len;
  double angle;
  double speed;
  double life;
  double decay;

  _ShootingStar({
    required this.x,
    required this.y,
    required this.len,
    required this.angle,
    required this.speed,
    required this.life,
    required this.decay,
  });

  factory _ShootingStar.random(Size size, math.Random rand) {
    return _ShootingStar(
      x: rand.nextDouble() * size.width * 0.7,
      y: rand.nextDouble() * size.height * 0.4,
      len: 90.0 + rand.nextDouble() * 140.0,
      angle: -0.38 + (rand.nextDouble() - 0.5) * 0.2,
      speed: 7.0 + rand.nextDouble() * 6.0,
      life: 1.0,
      decay: 0.025 + rand.nextDouble() * 0.02,
    );
  }
}

// ══════════════════════════════════════════════
// CUSTOM PAINTER
// ══════════════════════════════════════════════

class _BackgroundPainter extends CustomPainter {
  final LuminaThemeMode themeMode;
  final double time;
  final List<_CandyParticle> candyParticles;
  final List<_Cloud> clouds;
  final List<_SpaceParticle> spaceParticles;
  final List<_ShootingStar> shootingStars;

  _BackgroundPainter({
    required this.themeMode,
    required this.time,
    required this.candyParticles,
    required this.clouds,
    required this.spaceParticles,
    required this.shootingStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (themeMode == LuminaThemeMode.light) {
      _paintLight(canvas, size);
    } else {
      _paintDark(canvas, size);
    }
  }

  // ══════════════════════════════════════════════
  // LIGHT PAINTING: Candy Land
  // ══════════════════════════════════════════════

  void _paintLight(Canvas canvas, Size size) {
    // 1. Sky Gradient
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFFFAE8FF), // #FAE8FF
          Color(0xFFFFF0F9), // #FFF0F9
          Color(0xFFFFF5E6), // #FFF5E6
          Color(0xFFFFF8F0), // #FFF8F0
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. Soft Radial Bloom Top-Left
    final Paint bloomPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x61F0ABFC), // rgba(240,171,252,0.38)
          Color(0x00F0ABFC),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.25, 0),
        radius: size.width * 0.6,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bloomPaint);

    // 3. Hills
    _drawHills(canvas, size);

    // 4. Clouds
    for (var c in clouds) {
      _drawCloud(canvas, c);
    }

    // 5. Candy Particles
    for (var p in candyParticles) {
      _drawCandyShape(canvas, p);
    }
  }

  void _drawHills(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final hillDefs = [
      _HillDef(cx: W * 0.15, cy: H + 60, rx: W * 0.38, ry: 220, c1: const Color(0xFFF5D0FE), c2: const Color(0xFFE879F9), a: 0.52),
      _HillDef(cx: W * 0.85, cy: H + 80, rx: W * 0.32, ry: 200, c1: const Color(0xFFBBF7D0), c2: const Color(0xFF34D399), a: 0.50),
      _HillDef(cx: W * 0.50, cy: H + 90, rx: W * 0.45, ry: 240, c1: const Color(0xFFFDE68A), c2: const Color(0xFFFB923C), a: 0.62),
      _HillDef(cx: W * 0.05, cy: H + 40, rx: W * 0.30, ry: 180, c1: const Color(0xFFF9A8D4), c2: const Color(0xFFE879F9), a: 0.80),
      _HillDef(cx: W * 0.95, cy: H + 50, rx: W * 0.28, ry: 175, c1: const Color(0xFFF9A8D4), c2: const Color(0xFFA78BFA), a: 0.78),
      _HillDef(cx: W * 0.52, cy: H + 70, rx: W * 0.40, ry: 210, c1: const Color(0xFFBBF7D0), c2: const Color(0xFF67E8F9), a: 0.75),
    ];

    for (var d in hillDefs) {
      final Paint hp = Paint()
        ..shader = RadialGradient(
          colors: [d.c1, d.c2.withValues(alpha: 0.4)],
          center: Alignment.topCenter,
          radius: 1.0,
        ).createShader(Rect.fromLTRB(d.cx - d.rx, d.cy - d.ry, d.cx + d.rx, d.cy + d.ry))
        ..color = d.c1.withValues(alpha: d.a);
      
      canvas.save();
      canvas.translate(d.cx, d.cy);
      final hillPath = Path()..addOval(Rect.fromLTRB(-d.rx, -d.ry, d.rx, d.ry));
      canvas.drawPath(hillPath, hp);
      canvas.restore();
    }

    // Lollipops on the hills
    // Left side
    _drawLollipop(canvas, W * 0.10, H * 0.88, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.6);
    _drawLollipop(canvas, W * 0.25, H * 0.90, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.4);
    _drawLollipop(canvas, W * 0.18, H * 0.82, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.8);

    // Right side
    _drawLollipop(canvas, W * 0.72, H * 0.85, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.7);
    _drawLollipop(canvas, W * 0.88, H * 0.82, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.9);
    _drawLollipop(canvas, W * 0.78, H * 0.88, const Color(0xFFF472B6), const Color(0xFFFCA5A5), 0.5);
  }

  void _drawLollipop(Canvas canvas, double x, double y, Color c1, Color c2, double s) {
    canvas.save();
    // Lollipop Stick
    final Paint stickPaint = Paint()
      ..color = const Color(0xFFFCA5A5)
      ..strokeWidth = 4.0 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(x, y), Offset(x, y - 80 * s), stickPaint);
    
    // Candy Top (radial gradient circle)
    final double radius = 22.0 * s;
    final Offset center = Offset(x, y - 80 * s);
    final Paint candyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [c2, c1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, candyPaint);
    
    // Candy Gloss Highlight
    final Paint glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(x - 7 * s, y - 88 * s), 8 * s, glossPaint);
    
    canvas.restore();
  }

  void _drawCloud(Canvas canvas, _Cloud c) {
    canvas.save();
    final Paint cp = Paint()
      ..color = c.tint.withValues(alpha: c.alpha)
      ..style = PaintingStyle.fill;

    final double blobR = c.h * 0.52;
    final double rx = c.x;
    final double ry = c.y;

    // Draw main cloud body ellipses
    canvas.drawOval(Rect.fromCenter(center: Offset(rx, ry), width: c.w, height: c.h * 0.96), cp);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx - c.w * 0.18, ry - c.h * 0.28), width: blobR * 1.7, height: blobR * 1.7), cp);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx + c.w * 0.15, ry - c.h * 0.35), width: blobR * 2.0, height: blobR * 2.0), cp);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx + c.w * 0.32, ry - c.h * 0.18), width: blobR * 1.3, height: blobR * 1.3), cp);
    
    canvas.restore();
  }

  void _drawCandyShape(Canvas canvas, _CandyParticle p) {
    canvas.save();
    
    final Paint paint = Paint()
      ..color = p.color.withValues(alpha: p.alpha * (0.6 + 0.4 * math.sin(p.phase + time * 0.6)))
      ..style = PaintingStyle.fill;
    
    final double animatedX = p.x + math.sin(p.phase + time * 0.5) * 14.0;
    canvas.translate(animatedX, p.y);
    canvas.rotate(p.rot);

    if (p.shape == 'circle') {
      canvas.drawCircle(Offset.zero, p.size, paint);
    } else if (p.shape == 'diamond') {
      final path = Path()
        ..moveTo(0, -p.size)
        ..lineTo(p.size * 0.65, 0)
        ..lineTo(0, p.size)
        ..lineTo(-p.size * 0.65, 0)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      // Mini 5-pointed star
      final path = Path();
      for (int k = 0; k < 5; k++) {
        final double a = (k / 5) * math.pi * 2 - math.pi / 2;
        final double a2 = a + math.pi / 5;
        path.lineTo(math.cos(a) * p.size, math.sin(a) * p.size);
        path.lineTo(math.cos(a2) * p.size * 0.42, math.sin(a2) * p.size * 0.42);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    
    canvas.restore();
  }

  // ══════════════════════════════════════════════
  // DARK PAINTING: Space Mode
  // ══════════════════════════════════════════════

  void _paintDark(Canvas canvas, Size size) {
    // 1. Deep Space Gradient
    final Paint skyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.6),
        radius: 1.5,
        colors: const [
          Color(0xFF050218), // #050218
          Color(0xFF030112), // #030112
          Color(0xFF02010A), // #02010A
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. Nebulae
    _drawNebulae(canvas, size);

    // 3. Constellations
    _drawConstellations(canvas, size);

    // 4. Space Particles (Stars)
    for (var p in spaceParticles) {
      _drawSpaceStar(canvas, p);
    }

    // 5. Planets
    _drawPlanets(canvas, size);

    // 6. Shooting Stars
    _drawShootingStars(canvas);
  }

  void _drawNebulae(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final nebs = [
      _NebulaDef(x: W * 0.10, y: H * 0.10, r: 280, color: const Color(0xFF581C87)),
      _NebulaDef(x: W * 0.88, y: H * 0.15, r: 240, color: const Color(0xFF1E1B4B)),
      _NebulaDef(x: W * 0.55, y: H * 0.75, r: 200, color: const Color(0xFF047857)),
      _NebulaDef(x: W * 0.30, y: H * 0.55, r: 160, color: const Color(0xFF4F46E5)),
    ];

    for (int i = 0; i < nebs.length; i++) {
      final n = nebs[i];
      final double pulse = 0.3 + 0.18 * math.sin(time * 0.5 + i);
      final double radius = n.r * (1.0 + 0.08 * math.sin(time * 0.3 + i));
      
      final Paint np = Paint()
        ..shader = RadialGradient(
          colors: [
            n.color.withValues(alpha: pulse),
            n.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(n.x, n.y), radius: radius));

      canvas.save();
      canvas.translate(n.x, n.y);
      canvas.rotate(math.sin(i) * 0.4);
      
      // Draw nebula oval
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 2.6, height: radius * 2.0), np);
      canvas.restore();
    }
  }

  void _drawConstellations(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final constLines = [
      [const Offset(0.12, 0.08), const Offset(0.20, 0.15), const Offset(0.30, 0.10), const Offset(0.40, 0.18), const Offset(0.48, 0.13)],
      [const Offset(0.62, 0.06), const Offset(0.70, 0.13), const Offset(0.78, 0.08), const Offset(0.86, 0.15)],
      [const Offset(0.08, 0.30), const Offset(0.16, 0.38), const Offset(0.24, 0.33), const Offset(0.31, 0.42)],
    ];

    final double alpha = 0.18 + 0.06 * math.sin(time * 0.3);
    final Paint linePaint = Paint()
      ..color = const Color(0xFFA5B4FC).withValues(alpha: alpha)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (var pts in constLines) {
      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final double x = pts[i].dx * W;
        final double y = pts[i].dy * H;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      // Draw constellation star joint nodes
      for (var pt in pts) {
        final double x = pt.dx * W;
        final double y = pt.dy * H;
        final double nodeAlpha = 0.45 + 0.25 * math.sin(time * 0.8 + pt.dx * 10);
        final Paint jointPaint = Paint()
          ..color = const Color(0xFFA5B4FC).withValues(alpha: nodeAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 2.0, jointPaint);
      }
    }
  }

  void _drawSpaceStar(Canvas canvas, _SpaceParticle p) {
    final double starAlpha = p.alpha * (0.55 + 0.45 * math.sin(p.phase + time * 1.2));
    final Paint starPaint = Paint()
      ..color = p.color.withValues(alpha: starAlpha)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(p.x, p.y), p.size, starPaint);
  }

  void _drawPlanets(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final planetDefs = [
      _PlanetDef(px: 0.88, py: 0.10, r: 44, c1: const Color(0xFF7C3AED), c2: const Color(0xFF1E1B4B), glow: const Color(0x667C3AED)),
      _PlanetDef(px: 0.06, py: 0.65, r: 27, c1: const Color(0xFF065F46), c2: const Color(0xFF022C22), glow: const Color(0x73065F46)),
      _PlanetDef(px: 0.92, py: 0.78, r: 18, c1: const Color(0xFFB45309), c2: const Color(0xFF451A03), glow: const Color(0x66B45309)),
      _PlanetDef(px: 0.15, py: 0.22, r: 10, c1: const Color(0xFFBE185D), c2: const Color(0xFF500724), glow: const Color(0x80BE185D)),
    ];

    for (int i = 0; i < planetDefs.length; i++) {
      final p = planetDefs[i];
      final double x = p.px * W;
      final double y = p.py * H + math.sin(time * 0.4 + i) * 10.0;
      
      canvas.save();

      // Outer glow
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [p.glow, Colors.transparent],
          stops: const [0.36, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: p.r * 2.2));
      canvas.drawCircle(Offset(x, y), p.r * 2.2, glowPaint);

      // Planet body radial gradient
      final Paint planetPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [p.c1, p.c2],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: p.r));
      canvas.drawCircle(Offset(x, y), p.r, planetPaint);

      // Inner shadow overlay
      final Paint shadowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.3),
          colors: const [Colors.transparent, Color(0x80000000)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: p.r));
      canvas.drawCircle(Offset(x, y), p.r, shadowPaint);

      canvas.restore();
    }
  }

  void _drawShootingStars(Canvas canvas) {
    for (var s in shootingStars) {
      canvas.save();
      final double tailX = s.x + math.cos(s.angle) * s.len;
      final double tailY = s.y + math.sin(s.angle) * s.len;
      
      final Paint starPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: s.life * 0.9),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromPoints(Offset(s.x, s.y), Offset(tailX, tailY)))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(s.x, s.y), Offset(tailX, tailY), starPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return true; // continuous animation
  }
}

// Helper classes for painter parameters
class _HillDef {
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final Color c1;
  final Color c2;
  final double a;

  _HillDef({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.c1,
    required this.c2,
    required this.a,
  });
}

class _NebulaDef {
  final double x;
  final double y;
  final double r;
  final Color color;

  _NebulaDef({
    required this.x,
    required this.y,
    required this.r,
    required this.color,
  });
}

class _PlanetDef {
  final double px;
  final double py;
  final double r;
  final Color c1;
  final Color c2;
  final Color glow;

  _PlanetDef({
    required this.px,
    required this.py,
    required this.r,
    required this.c1,
    required this.c2,
    required this.glow,
  });
}
