import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/start_route.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _isNavigating = false;
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    // Initialize Lottie controller for slower, single-play animation
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // Slower animation (2.5 seconds)
    );
    // Notification permission is requested contextually after onboarding
    _startNavigationTimer();
  }

  /// Request notification permission on app start
  Future<void> _requestNotificationPermission() async {
    try {
      final granted = await NotificationService.instance.requestPermissions();
      debugPrint('SplashScreen: Notification permission ${granted ? "granted" : "denied"}');
    } catch (e) {
      debugPrint('SplashScreen: Error requesting notification permission - $e');
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _startNavigationTimer() {
    Future.delayed(AppConstants.splashDuration, () {
      if (mounted) {
        setState(() {
          _isNavigating = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final logoSize = isDesktop ? size.width * 0.10 : size.width * 0.25;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppConstants.darkBackground,
                    AppConstants.darkSurface,
                  ]
                : [
                    AppConstants.getPrimary(isDark).withOpacity(0.08),
                    AppConstants.lightBackground,
                  ],
          ),
        ),
        child: Center(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Animation
                  Lottie.asset(
                    'assets/animations/splash_logo.json',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    controller: _lottieController,
                    onLoaded: (composition) {
                      _lottieController.duration = composition.duration * 1.5; // Make it 1.5x slower
                      _lottieController.forward(from: 0); // Play once from start
                    },
                    repeat: false, // Don't loop
                    reverse: false, // Don't play in reverse
                  ),
                  const SizedBox(height: AppConstants.paddingXLarge),
                  // App Name
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Aura',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppConstants.getPrimary(isDark),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto',
                              ),
                        ),
                        TextSpan(
                          text: ' | ',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: isDark
                                    ? AppConstants.darkTextSecondary
                                    : AppConstants.lightTextSecondary,
                              ),
                        ),
                        TextSpan(
                          text: 'هالة',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppConstants.getPrimary(isDark),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  // Tagline
                  Text(
                    'app_tagline'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? AppConstants.darkTextSecondary
                              : AppConstants.lightTextSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingXLarge * 2),
                  // Simple Loading Indicator - Always keeps space to prevent layout shift
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: !_isNavigating
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              isDark
                                  ? AppConstants.primaryLight
                                  : AppConstants.getPrimary(isDark),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              // Auth State Listener
              _AuthNavigationHandler(
                isNavigating: _isNavigating,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget that handles navigation based on auth state
class _AuthNavigationHandler extends ConsumerStatefulWidget {
  final bool isNavigating;

  const _AuthNavigationHandler({
    required this.isNavigating,
  });

  @override
  ConsumerState<_AuthNavigationHandler> createState() =>
      _AuthNavigationHandlerState();
}

class _AuthNavigationHandlerState
    extends ConsumerState<_AuthNavigationHandler> {
  // Set before the post-frame callback is scheduled, so later rebuilds
  // cannot schedule a second navigation.
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    // Waits for the delay and for auth, guest and first-launch to finish
    // loading (null while any is loading).
    final destination = resolveSplashRoute(
      auth: ref.watch(authStateProvider),
      guest: ref.watch(guestModeProvider),
      firstLaunch: ref.watch(firstLaunchProvider),
    );

    if (!widget.isNavigating || destination == null || _navigated) {
      return const SizedBox.shrink();
    }

    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(destination);
      }
    });

    return const SizedBox.shrink();
  }
}
