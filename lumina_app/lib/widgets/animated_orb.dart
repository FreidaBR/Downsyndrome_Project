import 'package:flutter/material.dart';

class AnimatedOrb extends StatefulWidget {
  final double size;
  final bool isDark;

  const AnimatedOrb({
    super.key,
    this.size = 108.0,
    required this.isDark,
  });

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Rotation controller: rotates the outer gradient continuously over 16 seconds
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    // Pulse controller: pulses the inner core up/down over 3.5 seconds
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.02).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double orbSize = widget.size;
    final double innerSize = orbSize - 18.0;

    // Define colors & gradients based on theme
    final List<Color> lightOuterColors = const [
      Color(0xFFF9A8D4),
      Color(0xFFC4B5FD),
      Color(0xFF86EFAC),
      Color(0xFF7DD3FC),
      Color(0xFFF9A8D4),
    ];

    final List<Color> darkOuterColors = const [
      Color(0xFF818CF8),
      Color(0xFF34D399),
      Color(0xFF60A5FA),
      Color(0xFFA78BFA),
      Color(0xFF818CF8),
    ];

    final Alignment innerCenter = const Alignment(-0.4, -0.4);

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseAnimation]),
      builder: (context, child) {
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Glowing outer shadow layer 1
              Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.isDark
                          ? const Color(0xFF818CF8).withValues(alpha: 0.50)
                          : const Color(0xFFE879F9).withValues(alpha: 0.32),
                      blurRadius: widget.isDark ? 80.0 : 60.0,
                      spreadRadius: 2.0,
                    ),
                    BoxShadow(
                      color: widget.isDark
                          ? const Color(0xFF818CF8).withValues(alpha: 0.15)
                          : const Color(0xFFE879F9).withValues(alpha: 0.10),
                      blurRadius: widget.isDark ? 160.0 : 120.0,
                      spreadRadius: 10.0,
                    ),
                  ],
                ),
              ),
              
              // 2. Rotating Outer Gradient Ring
              Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159265,
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: widget.isDark ? darkOuterColors : lightOuterColors,
                    ),
                  ),
                ),
              ),

              // 3. Pulsing Inner Core
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: innerCenter,
                      radius: 0.65,
                      colors: widget.isDark
                          ? const [Color(0xFF1E1B4B), Color(0xFF04020F)]
                          : const [Color(0xFFFFF0FF), Color(0xFFF5C0FF)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
