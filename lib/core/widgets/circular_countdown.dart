import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/number_formatter.dart';

/// A beautiful circular countdown timer for next prayer
class CircularCountdownTimer extends StatefulWidget {
  final DateTime targetTime;
  final String? prayerName;
  final String? prayerTime;
  final Color? primaryColor;
  final Color? backgroundColor;
  final VoidCallback? onComplete;

  const CircularCountdownTimer({
    super.key,
    required this.targetTime,
    this.prayerName,
    this.prayerTime,
    this.primaryColor,
    this.backgroundColor,
    this.onComplete,
  });

  @override
  State<CircularCountdownTimer> createState() => _CircularCountdownTimerState();
}

class _CircularCountdownTimerState extends State<CircularCountdownTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  Timer? _updateTimer;
  Duration _remaining = Duration.zero;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _startUpdateTimer();
  }

  @override
  void didUpdateWidget(CircularCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTime != oldWidget.targetTime) {
      _completed = false;
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final now = DateTime.now();
    _remaining = widget.targetTime.difference(now);

    if (_remaining.isNegative && !_completed) {
      _remaining = Duration.zero;
      _completed = true;
      widget.onComplete?.call();
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final wasNegative = _remaining.isNegative;
      _updateRemaining();

      if (_remaining.isNegative && !wasNegative && !_completed) {
        _completed = true;
        widget.onComplete?.call();
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final primaryColor = widget.primaryColor ?? AppConstants.getPrimary(isDark);
    final backgroundColor =
        widget.backgroundColor ?? (isDark ? AppConstants.darkCard : AppConstants.lightCard);

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Ring
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(180, 180),
                painter: _CountdownPainter(
                  progress: _progressAnimation.value,
                  primaryColor: primaryColor,
                  trackColor:
                      isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  remaining: _remaining,
                ),
              );
            },
          ),

          // Center Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prayer Name (large)
              if (widget.prayerName != null) ...[
                Text(
                  widget.prayerName!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // Main Countdown Display
              _buildTimeDisplay(context, hours, minutes, seconds, isArabic, isDark),

              // Prayer Time (small)
              if (widget.prayerTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.prayerTime!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: primaryColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(
    BuildContext context,
    int hours,
    int minutes,
    int seconds,
    bool isArabic,
    bool isDark,
  ) {
    String display;

    if (hours > 0) {
      // Show hours and minutes
      final h = isArabic
          ? NumberFormatter.withArabicNumeralsByLanguage('$hours', 'ar')
          : '$hours';
      final m = isArabic
          ? NumberFormatter.withArabicNumeralsByLanguage('$minutes', 'ar')
          : '${minutes.toString().padLeft(2, '0')}';
      display = isArabic ? '$h س $m د' : '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else {
      // Show minutes and seconds
      display = isArabic
          ? '$minutes:$seconds'
          : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    // Convert to Arabic numerals if needed
    if (isArabic) {
      display = NumberFormatter.withArabicNumeralsByLanguage(display, 'ar');
    }

    return Text(
      display,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color trackColor;
  final Duration remaining;

  _CountdownPainter({
    required this.progress,
    required this.primaryColor,
    required this.trackColor,
    required this.remaining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Track (background circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress (foreground arc)
    if (remaining.inSeconds > 0) {
      // Calculate progress based on seconds remaining (max 1 hour)
      final totalSeconds = remaining.inSeconds;
      final maxSeconds = 3600; // 1 hour max
      final progressValue = (totalSeconds / maxSeconds).clamp(0.0, 1.0);

      final progressPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progressValue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        sweepAngle * this.progress,
        false,
        progressPaint,
      );
    }

    // Inner decorative ring
    final innerPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 15, innerPaint);
  }

  @override
  bool shouldRepaint(_CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.remaining != remaining;
  }
}

/// Compact version of countdown for use in cards
class CompactCountdown extends StatelessWidget {
  final DateTime targetTime;
  final String? label;
  final Color? color;

  const CompactCountdown({
    super.key,
    required this.targetTime,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final primaryColor = color ?? AppConstants.getPrimary(isDark);

    final now = DateTime.now();
    final difference = targetTime.difference(now);

    if (difference.isNegative) {
      return const SizedBox.shrink();
    }

    String countdown;
    if (difference.inHours > 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      countdown = isArabic ? '$hours س $minutes د' : '${hours}h ${minutes}m';
    } else {
      final minutes = difference.inMinutes;
      final seconds = difference.inSeconds % 60;
      countdown = isArabic
          ? '$minutes:$seconds'
          : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    // Convert to Arabic numerals if needed
    if (isArabic) {
      countdown = NumberFormatter.withArabicNumeralsByLanguage(countdown, 'ar');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                color: primaryColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.schedule,
            size: 14,
            color: primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            countdown,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
