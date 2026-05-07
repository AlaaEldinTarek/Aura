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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseAnim = CurvedAnimation(parent: _pulseController, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fadeController.reset();
      _fadeController.forward();
      _pulseController.reset();
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final step = widget.steps[widget.currentIndex];
    final isLast = widget.currentIndex == widget.steps.length - 1;
    final screenSize = MediaQuery.of(context).size;

    final box = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    Rect targetRect = Rect.zero;
    if (box != null) {
      targetRect = box.localToGlobal(Offset.zero) & box.size;
    }

    final tooltipTop = targetRect.bottom + 12;
    final tooltipFitsBelow = tooltipTop + 200 < screenSize.height;
    final tooltipTop2 = tooltipFitsBelow ? tooltipTop : targetRect.top - 200;

    final primary = AppConstants.getPrimary(isDark);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Dark overlay + cutout + pulsing border (all in one animated painter)
          GestureDetector(
            onTap: widget.onSkip,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                painter: _OverlayPainter(
                  targetRect: targetRect,
                  overlayColor: Colors.black.withOpacity(0.75),
                  borderColor: primary,
                  radius: 12,
                  pulse: _pulseAnim.value,
                ),
                size: screenSize,
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
                  Text(
                    '${'tutorial_step'.tr()} ${widget.currentIndex + 1} ${'tutorial_of'.tr()} ${widget.steps.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.titleKey.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.bodyKey.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
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

/// Paints: dark overlay with cutout + solid border + pulsing expanding ring
class _OverlayPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final Color borderColor;
  final double radius;
  final double pulse; // 0.0 → 1.0, repeating

  _OverlayPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.borderColor,
    required this.radius,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Dark overlay with clear cutout ────────────────────────────────────
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = overlayColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect.inflate(4), Radius.circular(radius)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    if (targetRect == Rect.zero) return;

    // ── 2. Solid border ───────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect.inflate(4), Radius.circular(radius)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 3. Pulsing expanding ring ─────────────────────────────────────────────
    final expand = pulse * 22.0;
    final opacity = (1.0 - pulse) * 0.65;
    if (pulse > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect.inflate(4 + expand),
          Radius.circular(radius + expand),
        ),
        Paint()
          ..color = borderColor.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.5 * (1 - pulse)).clamp(0.5, 3.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.targetRect != targetRect || old.pulse != pulse;
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
    builder: (_) => Material(
      color: Colors.transparent,
      child: TutorialOverlay(
        steps: steps,
        currentIndex: currentStep,
        onNext: nextStep,
        onSkip: removeEntry,
      ),
    ),
  );

  Overlay.of(context).insert(entry);
}
