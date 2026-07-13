import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Square "Bento Box" scan frame with rounded corner brackets and an
/// animated horizontal laser line that sweeps top-to-bottom.
class ScannerOverlay extends StatefulWidget {
  final double size;
  const ScannerOverlay({super.key, this.size = 260});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dimmed backdrop with a transparent square cutout is handled by
          // the parent (ColorFiltered/CustomPainter in scanner_screen.dart).
          ..._buildCorners(),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: 8 + _controller.value * (widget.size - 16),
                left: 8,
                right: 8,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.accent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const double bracketLength = 32;
    const double thickness = 4;
    const radius = Radius.circular(16);

    Widget bracket({required Alignment alignment}) {
      final isTop = alignment.y < 0;
      final isLeft = alignment.x < 0;
      return Align(
        alignment: alignment,
        child: SizedBox(
          width: bracketLength,
          height: bracketLength,
          child: CustomPaint(
            painter: _CornerPainter(
              isTop: isTop,
              isLeft: isLeft,
              thickness: thickness,
              radius: radius,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }

    return [
      bracket(alignment: Alignment.topLeft),
      bracket(alignment: Alignment.topRight),
      bracket(alignment: Alignment.bottomLeft),
      bracket(alignment: Alignment.bottomRight),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final double thickness;
  final Radius radius;
  final Color color;

  _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.thickness,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final r = radius.x;

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, r);
      path.arcToPoint(Offset(r, 0), radius: radius);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - r, 0);
      path.arcToPoint(Offset(size.width, r), radius: radius);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(r, size.height);
      path.arcToPoint(Offset(0, size.height - r), radius: radius, clockwise: false);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width - r, size.height);
      path.arcToPoint(Offset(size.width, size.height - r), radius: radius);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
