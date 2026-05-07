import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';

class TutorialStep {
  final GlobalKey targetKey;
  final String titleKey;
  final String bodyKey;

  const TutorialStep({
    required this.targetKey,
    required this.titleKey,
    required this.bodyKey,
  });
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final step = widget.steps[widget.currentIndex];
    final isLast = widget.currentIndex == widget.steps.length - 1;

    // Get target widget position
    final box = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    Rect targetRect = Rect.zero;
    if (box != null) {
      targetRect = box.localToGlobal(Offset.zero) & box.size;
    }

    // Tooltip position: below or above the target
    final tooltipTop = targetRect.bottom + 12;
    final tooltipFitsBelow = tooltipTop + 200 < screenSize.height;
    final tooltipTop2 = tooltipFitsBelow ? tooltipTop : targetRect.top - 200;
    final pointerFromTop = !tooltipFitsBelow;

    final primary = AppConstants.getPrimary(isDark);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Dark overlay with cutout
          GestureDetector(
            onTap: widget.onSkip,
            child: CustomPaint(
              painter: _OverlayPainter(
                targetRect: targetRect,
                overlayColor: Colors.black.withOpacity(0.75),
                radius: 12,
              ),
              size: screenSize,
            ),
          ),

          // Highlight border around target
          if (targetRect != Rect.zero)
            Positioned.fromRect(
              rect: targetRect.inflate(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary, width: 2.5),
                ),
              ),
            ),

          // Tooltip bubble
          Positioned(
            left: 16,
            right: 16,
            top: tooltipTop2.clamp(16.0, screenSize.height - 220),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step counter
                  Text(
                    '${'tutorial_step'.tr()} ${widget.currentIndex + 1} ${'tutorial_of'.tr()} ${widget.steps.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    step.titleKey.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Body
                  Text(
                    step.bodyKey.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: widget.onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white38 : Colors.black38,
                        ),
                        child: Text('tutorial_skip'.tr()),
                      ),
                      ElevatedButton(
                        onPressed: widget.onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: Text(
                          isLast ? 'tutorial_done'.tr() : 'tutorial_next'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dark overlay with a rounded-rect cutout
class _OverlayPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final double radius;

  _OverlayPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer is required for BlendMode.clear to punch through correctly
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final paint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final cutout = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(
      targetRect.inflate(4),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, cutout);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

/// Shows the tutorial as a full-screen overlay
void showTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  required VoidCallback onDone,
}) {
  int currentStep = 0;
  late OverlayEntry entry;

  void removeEntry() {
    entry.remove();
    onDone();
  }

  void nextStep() {
    if (currentStep < steps.length - 1) {
      currentStep++;
      entry.markNeedsBuild();
    } else {
      removeEntry();
    }
  }

  entry = OverlayEntry(
    builder: (_) {
      return Material(
        color: Colors.transparent,
        child: TutorialOverlay(
          steps: steps,
          currentIndex: currentStep,
          onNext: nextStep,
          onSkip: removeEntry,
        ),
      );
    },
  );

  Overlay.of(context).insert(entry);
}
