import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final String badge;

  TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.badge,
  });
}

class OnboardingTourWidget extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onClose;
  final Color themeColor;

  const OnboardingTourWidget({
    super.key,
    required this.steps,
    required this.onClose,
    required this.themeColor,
  });

  @override
  State<OnboardingTourWidget> createState() => _OnboardingTourWidgetState();
}

class _OnboardingTourWidgetState extends State<OnboardingTourWidget> with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  Rect? _targetRect;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetBounds();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTargetBounds() {
    if (_currentStepIndex >= widget.steps.length) return;
    final step = widget.steps[_currentStepIndex];
    final context = step.targetKey.currentContext;

    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );

      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          setState(() {
            _targetRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
          });
        }
      });
    } else {
      setState(() {
        _targetRect = null;
      });
    }
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _targetRect = null;
      });
      _updateTargetBounds();
    } else {
      widget.onClose();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _targetRect = null;
      });
      _updateTargetBounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStepIndex];
    final isLast = _currentStepIndex == widget.steps.length - 1;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: SpotlightPainter(
                targetRect: _targetRect,
                maskColor: const Color(0xCC0F172A),
                pulseValue: _pulseController.value,
                highlightColor: widget.themeColor,
              ),
            );
          },
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: widget.themeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        step.badge.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.body,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(widget.steps.length, (index) {
                          final isActive = index == _currentStepIndex;
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            height: 6,
                            width: isActive ? 16 : 6,
                            decoration: BoxDecoration(
                              color: isActive ? widget.themeColor : widget.themeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      Row(
                        children: [
                          if (_currentStepIndex > 0) ...[
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _prevStep,
                              child: Text(
                                "Back",
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: _nextStep,
                            child: Text(
                              isLast ? "Finish" : "Next",
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color maskColor;
  final double pulseValue;
  final Color highlightColor;

  SpotlightPainter({
    required this.targetRect,
    required this.maskColor,
    required this.pulseValue,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = maskColor;

    if (targetRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    final maskPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final borderPadding = 8.0 + (pulseValue * 4.0);
    final holeRect = targetRect!.inflate(borderPadding);
    final holePath = Path()..addRRect(
      RRect.fromRectAndRadius(holeRect, const Radius.circular(16)),
    );

    final finalPath = Path.combine(PathOperation.difference, maskPath, holePath);
    canvas.drawPath(finalPath, paint);

    final borderPaint = Paint()
      ..color = highlightColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(holeRect, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.highlightColor != highlightColor;
  }
}
