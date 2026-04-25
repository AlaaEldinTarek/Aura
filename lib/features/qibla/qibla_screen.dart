import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/offline_banner.dart';

/// Qibla Compass Screen - Shows direction to Mecca
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  // Kaaba coordinates
  static const double _kaabaLatitude = 21.4225;
  static const double _kaabaLongitude = 39.8262;

  double? _heading;
  double _smoothedHeading = 0;
  Position? _currentPosition;
  double? _qiblaDirection;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCompass();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCompass() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current location
      final locationService = LocationService.instance;
      final locationData = await locationService.getBestLocation();

      setState(() {
        _currentPosition = Position(
          latitude: locationData.latitude,
          longitude: locationData.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        // Calculate Qibla direction
        _qiblaDirection = _calculateQiblaDirection(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      });

      // Listen to compass heading with smoothing
      _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
        if (event.heading == null) return;
        if (!mounted) return;
        // Apply low-pass filter for smooth compass movement
        final rawHeading = event.heading!;
        if (_heading == null) {
          _smoothedHeading = rawHeading;
        } else {
          // Handle 360/0 degree wraparound
          double diff = rawHeading - _smoothedHeading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;
          _smoothedHeading += diff * 0.3;
          if (_smoothedHeading < 0) _smoothedHeading += 360;
          if (_smoothedHeading >= 360) _smoothedHeading -= 360;
        }
        setState(() {
          _heading = _smoothedHeading;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calculate Qibla direction using spherical trigonometry
  double _calculateQiblaDirection(double latitude, double longitude) {
    final lat1 = _degreesToRadians(latitude);
    final lat2 = _degreesToRadians(_kaabaLatitude);
    final longDiff = _degreesToRadians(_kaabaLongitude - longitude);

    // Calculate Qibla angle
    final y = math.sin(longDiff);
    final x = math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(longDiff);

    var qibla = math.atan2(y, x);
    qibla = _radiansToDegrees(qibla);

    // Normalize to 0-360
    if (qibla < 0) {
      qibla += 360;
    }

    return qibla;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  /// Calculate distance to Kaaba in kilometers
  double _calculateDistanceToKaaba() {
    if (_currentPosition == null) return 0.0;

    const double earthRadius = 6371; // km

    final lat1 = _degreesToRadians(_currentPosition!.latitude);
    final lat2 = _degreesToRadians(_kaabaLatitude);
    final latDiff = _degreesToRadians(_kaabaLatitude - _currentPosition!.latitude);
    final longDiff = _degreesToRadians(_kaabaLongitude - _currentPosition!.longitude);

    final a = math.pow(math.sin(latDiff / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(longDiff / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: ConnectivityWrapper(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  isArabic ? 'القبلة' : 'Qibla',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: _buildContent(context, isDark, isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, bool isArabic) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(context, _errorMessage!, isDark);
    }

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        children: [
          // Location info
          _buildLocationInfo(context, isDark, isArabic),

          const SizedBox(height: AppConstants.paddingLarge),

          // Compass
          _buildCompass(context, isDark, isArabic),

          const SizedBox(height: AppConstants.paddingLarge),

          // Instructions
          _buildInstructions(context, isDark, isArabic),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(BuildContext context, bool isDark, bool isArabic) {
    final distance = _calculateDistanceToKaaba();
    final distanceText = isArabic
        ? '${distance.toStringAsFixed(0)} كم'
        : '${distance.toStringAsFixed(0)} km';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                color: AppConstants.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'المسافة إلى مكة' : 'Distance to Makkah',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            distanceText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass(BuildContext context, bool isDark, bool isArabic) {
    final heading = _heading ?? 0;
    final qiblaDirection = _qiblaDirection ?? 0;

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Compass circle with animated rotation
          Center(
            child: AnimatedRotation(
              turns: -heading / 360,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppConstants.primaryColor.withValues(alpha: 0.3),
                            AppConstants.accentCyan.withValues(alpha: 0.3),
                          ]
                        : [
                            AppConstants.primaryColor.withValues(alpha: 0.1),
                            AppConstants.accentCyan.withValues(alpha: 0.1),
                          ],
                  ),
                  border: Border.all(
                    color: AppConstants.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: CompassPainter(
                    heading: 0, // heading is now handled by AnimatedRotation
                    qiblaDirection: qiblaDirection,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ),

          // Center Kaaba icon
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mosque,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context, bool isDark, bool isArabic) {
    final headingDiff = _qiblaDirection != null && _heading != null
        ? (_qiblaDirection! - _heading!).abs()
        : 0.0;

    String instruction;
    Color instructionColor;

    if (headingDiff < 5) {
      instruction = isArabic ? 'أنت تتجه نحو القبلة' : 'You are facing Qibla';
      instructionColor = Colors.green;
    } else if (headingDiff < 20) {
      instruction = isArabic ? 'أنت قريب من القبلة' : 'Close to Qibla';
      instructionColor = Colors.orange;
    } else {
      instruction = isArabic ? 'دور نحو اليمين' : 'Turn to the right';
      instructionColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            instruction,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: instructionColor,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'حمل جهازك بشكل مسطح' : 'Hold your device flat',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppConstants.error,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            isDark ? 'خطأ في تحميل القبلة' : 'Error loading Qibla',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          ElevatedButton.icon(
            onPressed: _initializeCompass,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the compass
class CompassPainter extends CustomPainter {
  final double heading;
  final double qiblaDirection;
  final bool isDark;

  CompassPainter({
    required this.heading,
    required this.qiblaDirection,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    final tickPaint = Paint()
      ..color = isDark ? Colors.white38 : Colors.black38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw tick marks every 30 degrees
    for (int i = 0; i < 12; i++) {
      final angle = i * 30.0;
      final radians = (angle - 90) * math.pi / 180;
      final isCardinal = i % 3 == 0;
      final tickLength = isCardinal ? 14.0 : 8.0;

      final outerX = center.dx + radius * math.cos(radians);
      final outerY = center.dy + radius * math.sin(radians);
      final innerX = center.dx + (radius - tickLength) * math.cos(radians);
      final innerY = center.dy + (radius - tickLength) * math.sin(radians);

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        isCardinal ? majorTickPaint : tickPaint,
      );
    }

    // Draw cardinal direction labels
    final cardinalLabels = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    final cardinalColors = {
      0: Colors.red,
      90: isDark ? Colors.white60 : Colors.black45,
      180: isDark ? Colors.white60 : Colors.black45,
      270: isDark ? Colors.white60 : Colors.black45,
    };

    cardinalLabels.forEach((angle, label) {
      final radians = (angle - 90) * math.pi / 180;
      final labelRadius = radius - 24;
      final x = center.dx + labelRadius * math.cos(radians);
      final y = center.dy + labelRadius * math.sin(radians);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: cardinalColors[angle] ?? (isDark ? Colors.white : Colors.black),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    });

    // Draw intercardinal labels (smaller)
    final intercardinalLabels = {45: 'NE', 135: 'SE', 225: 'SW', 315: 'NW'};
    intercardinalLabels.forEach((angle, label) {
      final radians = (angle - 90) * math.pi / 180;
      final labelRadius = radius - 22;
      final x = center.dx + labelRadius * math.cos(radians);
      final y = center.dy + labelRadius * math.sin(radians);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isDark ? Colors.white24 : Colors.black26,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    });

    // Draw Qibla direction marker
    final qiblaAngle = (qiblaDirection) * math.pi / 180;
    final qiblaPaint = Paint()
      ..color = AppConstants.primaryColor
      ..strokeWidth = 4;

    final qiblaX = center.dx + (radius * 0.6) * math.cos(qiblaAngle - math.pi / 2);
    final qiblaY = center.dy + (radius * 0.6) * math.sin(qiblaAngle - math.pi / 2);

    canvas.drawCircle(Offset(qiblaX, qiblaY), 10, qiblaPaint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(qiblaX, qiblaY), 12, qiblaPaint..style = PaintingStyle.stroke);

    // Draw Qibla line from center to marker
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.45) * math.cos(qiblaAngle - math.pi / 2),
        center.dy + (radius * 0.45) * math.sin(qiblaAngle - math.pi / 2),
      ),
      Paint()
        ..color = AppConstants.primaryColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.qiblaDirection != qiblaDirection;
  }
}
