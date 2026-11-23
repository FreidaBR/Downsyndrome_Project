import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../core/theme.dart';

class CustomCursor extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const CustomCursor({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  State<CustomCursor> createState() => _CustomCursorState();
}

class _CustomCursorState extends State<CustomCursor> {
  Offset _pointerOffset = Offset.zero;
  bool _visible = false;
  bool _isHoveringInteractive = false;

  // Check if platform supports hover mouse cursors natively
  bool get _hasMouseSupport {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false; // Platform check throws on web if not careful, handled by kIsWeb
    }
  }

  @override
  Widget build(BuildContext context) {
    // If touch platform, disable custom cursor entirely
    if (!_hasMouseSupport) {
      return widget.child;
    }

    final Color cursorColor = widget.isDark
        ? LuminaColors.darkCursor
        : LuminaColors.lightCursor;

    // Check widget tree if hover state is registered globally
    // We can also let child components notify of hover, or monitor hover events globally.
    // By wrapping the whole app, we intercept hover events.
    return MouseRegion(
      cursor: SystemMouseCursors.none, // Hide default cursor
      onEnter: (_) => setState(() => _visible = true),
      onExit: (_) => setState(() => _visible = false),
      onHover: (event) {
        setState(() {
          _pointerOffset = event.position;
          _visible = true;
        });
      },
      child: Stack(
        children: [
          // The actual application
          NotificationListener<_HoverNotification>(
            onNotification: (notification) {
              setState(() {
                _isHoveringInteractive = notification.isHovering;
              });
              return true;
            },
            child: widget.child,
          ),
          
          // Custom Cursor Overlay
          if (_visible) ...[
            // 1. The Ring (animated position following the mouse with a slight lag/ease)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              left: _pointerOffset.dx - (_isHoveringInteractive ? 21.0 : 14.0),
              top: _pointerOffset.dy - (_isHoveringInteractive ? 21.0 : 14.0),
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isHoveringInteractive ? 0.35 : 0.50,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHoveringInteractive ? 42.0 : 28.0,
                    height: _isHoveringInteractive ? 42.0 : 28.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cursorColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // 2. The Dot (tracks mouse coordinates immediately without lag)
            Positioned(
              left: _pointerOffset.dx - 3.0,
              top: _pointerOffset.dy - 3.0,
              child: IgnorePointer(
                child: Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cursorColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Notification to communicate hover states from buttons up the tree
class _HoverNotification extends Notification {
  final bool isHovering;
  _HoverNotification(this.isHovering);
}

// Global helper widget to wrap buttons / interactive components
class InteractiveCursorRegion extends StatelessWidget {
  final Widget child;

  const InteractiveCursorRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _HoverNotification(true).dispatch(context),
      onExit: (_) => _HoverNotification(false).dispatch(context),
      child: child,
    );
  }
}
