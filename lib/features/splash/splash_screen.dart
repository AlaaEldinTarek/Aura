import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/notification_service.dart';

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
    // Defer permission request to avoid blocking the splash animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _requestNotificationPermission();
    });
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
    final logoSize = size.width * 0.25;

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
                    AppConstants.primaryColor.withOpacity(0.08),
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
                                color: AppConstants.primaryColor,
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
                                color: AppConstants.primaryColor,
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
                                  : AppConstants.primaryColor,
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
class _AuthNavigationHandler extends ConsumerWidget {
  final bool isNavigating;

  const _AuthNavigationHandler({
    required this.isNavigating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    final firstLaunchAsync = ref.watch(firstLaunchProvider);
    final isFirstLaunch = firstLaunchAsync.value ?? true;

    final guestModeAsync = ref.watch(guestModeProvider);
    final isGuest = guestModeAsync.value ?? false;

    if (!isNavigating) {
      return const SizedBox.shrink();
    }

    if (authState.isLoading || guestModeAsync.isLoading) {
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        String destination;
        if (isGuest) {
          destination = isFirstLaunch ? '/onboarding' : '/home';
        } else if (user != null) {
          destination = isFirstLaunch ? '/onboarding' : '/home';
        } else {
          destination = '/login';
        }

        Navigator.of(context).pushReplacementNamed(destination);
      }
    });

    return const SizedBox.shrink();
  }
}
