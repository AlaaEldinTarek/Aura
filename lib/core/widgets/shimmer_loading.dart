import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// A shimmer loading effect widget
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = widget.baseColor ??
        (isDark ? AppConstants.darkCard : AppConstants.lightCard);
    final highlightColor = widget.highlightColor ??
        (isDark ? AppConstants.darkSurface : Colors.grey[100]);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor ?? baseColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Shimmer box placeholder
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Shimmer list tile placeholder
class ShimmerListTile extends StatelessWidget {
  final bool leading;
  final bool trailing;

  const ShimmerListTile({
    super.key,
    this.leading = true,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: Row(
        children: [
          if (leading) ...[
            const ShimmerBox(width: 40, height: 40),
            const SizedBox(width: AppConstants.paddingMedium),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 150,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          if (trailing) ...[
            const SizedBox(width: AppConstants.paddingMedium),
            const ShimmerBox(width: 24, height: 24),
          ],
        ],
      ),
    );
  }
}

/// Shimmer card placeholder
class ShimmerCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShimmerLoading(
      child: Container(
        width: width,
        height: height ?? 80,
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.grey[200],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Wrapper that applies shimmer to any widget by cloning its shape
/// Usage: ShimmerWrapper(child: MyRealWidget(with: fake_data))
class ShimmerWrapper extends StatelessWidget {
  final Widget child;

  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(child: child);
  }
}

/// Shimmer that mirrors the location header (icon + city name)
class ShimmerLocationHeader extends StatelessWidget {
  const ShimmerLocationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingSmall),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerBox(
              width: 20,
              height: 20,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 6),
            ShimmerBox(
              width: 100,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer that mirrors the date header (blue bar with hijri/gregorian)
class ShimmerDateHeader extends StatelessWidget {
  const ShimmerDateHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.grey[200],
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Row(
          children: [
            // Left date
            ShimmerBox(
              width: 100,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const Spacer(),
            // Center badge
            ShimmerBox(
              width: 50,
              height: 24,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            ),
            const Spacer(),
            // Right date
            ShimmerBox(
              width: 100,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer that mirrors the circular countdown timer (180x180 circle)
class ShimmerCircularCountdown extends StatelessWidget {
  const ShimmerCircularCountdown({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppConstants.darkCard : Colors.grey[200],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerBox(
              width: 70,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            ShimmerBox(
              width: 80,
              height: 20,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            ShimmerBox(
              width: 60,
              height: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer that mirrors a single PrayerCard
/// Matches the real layout: [52x52 icon] [name + time + iqamah] [button]
class ShimmerPrayerCard extends StatelessWidget {
  const ShimmerPrayerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.grey[200],
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
          ),
        ),
        child: Row(
          children: [
            // Prayer icon (52x52 square with rounded corners)
            ShimmerBox(
              width: 52,
              height: 52,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            const SizedBox(width: AppConstants.paddingMedium),

            // Prayer info (name, time, iqamah)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prayer name
                  ShimmerBox(
                    width: 80,
                    height: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  // Prayer time
                  ShimmerBox(
                    width: 100,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  // Iqamah time
                  ShimmerBox(
                    width: 120,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

            // Action button (mark as prayed / countdown)
            ShimmerBox(
              width: 70,
              height: 30,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer that mirrors the Quick Actions section
class ShimmerQuickActions extends StatelessWidget {
  const ShimmerQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.grey[200],
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            ShimmerBox(
              width: 100,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            // Two action buttons
            Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 60,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 60,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer for a section header text line
class ShimmerSectionHeader extends StatelessWidget {
  final double width;
  const ShimmerSectionHeader({super.key, this.width = 160});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: ShimmerBox(
        width: width,
        height: 20,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Shimmer for a section label text line
class ShimmerSectionLabel extends StatelessWidget {
  final double width;
  const ShimmerSectionLabel({super.key, this.width = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: ShimmerBox(
        width: width,
        height: 16,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
