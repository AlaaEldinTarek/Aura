import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/shared_preferences_service.dart';
import 'core/services/firebase_options.dart';
import 'core/services/analytics_service.dart';
import 'core/services/prayer_widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/adhan_player_service.dart';
import 'core/services/prayer_alarm_service.dart';
import 'core/services/background_service_manager.dart';
import 'core/providers/preferences_provider.dart';
import 'core/providers/auth_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/onboarding/preference_screen.dart';
import 'features/main/main_wrapper_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/prayer/prayer_tracking_screen.dart';
import 'features/prayer/prayer_report_screen.dart';
import 'features/dhikl/dhikr_stats_screen.dart';
import 'features/dhikl/dhikr_screen.dart';
import 'features/achievements/achievements_screen.dart';
import 'core/services/offline_queue_service.dart';
import 'features/tasks/task_form_screen.dart';
import 'core/models/task.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/iqama_settings_screen.dart';
import 'features/settings/adhan_downloads_screen.dart';
import 'features/qibla/qibla_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, st) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Analytics with error handling
  try {
    await AnalyticsService.instance.initialize();
    debugPrint('✅ Analytics initialized');
  } catch (e, st) {
    debugPrint('❌ Analytics initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Easy Localization with error handling
  try {
    await EasyLocalization.ensureInitialized();
    debugPrint('✅ EasyLocalization initialized');
  } catch (e, st) {
    debugPrint('❌ EasyLocalization initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Shared Preferences with error handling
  late SharedPreferencesService prefsService;
  try {
    prefsService = await SharedPreferencesService.getInstance();
    await prefsService.ensureInitialized();
    debugPrint('✅ SharedPreferences initialized');
  } catch (e, st) {
    debugPrint('❌ SharedPreferences initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
    prefsService = await SharedPreferencesService.getInstance();
    await prefsService.ensureInitialized();
  }

  // Initialize Prayer Widget Service with error handling
  try {
    await PrayerWidgetService.init();
    debugPrint('✅ PrayerWidgetService initialized');
  } catch (e, st) {
    debugPrint('❌ PrayerWidgetService initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Notification Service with error handling
  try {
    await NotificationService.instance.initialize();
    debugPrint('✅ NotificationService initialized');
  } catch (e, st) {
    debugPrint('❌ NotificationService initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Adhan Player Service with error handling
  try {
    await AdhanPlayerService.instance.initialize();
    debugPrint('✅ AdhanPlayerService initialized');
  } catch (e, st) {
    debugPrint('❌ AdhanPlayerService initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Prayer Alarm Service with error handling (for native adhan alarms)
  try {
    await PrayerAlarmService.instance.initialize();
    debugPrint('✅ PrayerAlarmService initialized');
  } catch (e, st) {
    debugPrint('❌ PrayerAlarmService initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Background Service Manager with error handling (for keeping app alive)
  try {
    await BackgroundServiceManager.instance.initialize();
    debugPrint('✅ BackgroundServiceManager initialized');
  } catch (e, st) {
    debugPrint('❌ BackgroundServiceManager initialization failed: $e');
    debugPrint('📍 Stack trace: $st');
  }

  // Initialize Offline Queue Service
  try {
    await OfflineQueueService.instance.initialize();
  } catch (e) {
    debugPrint('❌ OfflineQueueService initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesServiceProvider.overrideWithValue(prefsService),
      ],
      child: const AuraApp(),
    ),
  );
}

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final languageAsync = ref.watch(languageProvider);

    return themeModeAsync.when(
      data: (themeMode) => languageAsync.when(
        data: (language) {
          // Don't use ValueKey - it causes full app reload on theme change
          return EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            startLocale: Locale(language),
            useOnlyLangCode: true,
            saveLocale: false,
            child: AuraAppMaterial(themeMode: themeMode),
          );
        },
        loading: () => const MaterialApp(
          title: 'Aura - هالة',
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, __) => const MaterialApp(
          title: 'Aura - هالة',
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Text('Error loading preferences'),
            ),
          ),
        ),
      ),
      loading: () => const MaterialApp(
        title: 'Aura - هالة',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, __) => MaterialApp(
        title: 'Aura - هالة',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: Text('Error loading theme'),
          ),
        ),
      ),
    );
  }
}

class AuraAppMaterial extends ConsumerWidget {
  final String themeMode;

  const AuraAppMaterial({super.key, required this.themeMode});

  bool _isAmoled(String mode) => mode == 'amoled';

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'amoled':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageAsync = ref.watch(languageProvider);
    final dynamicColorAsync = ref.watch(dynamicColorProvider);
    final isAmoled = _isAmoled(themeMode);
    final effectiveDarkTheme = isAmoled ? AppTheme.amoledTheme : AppTheme.darkTheme;
    final useDynamicColor = dynamicColorAsync.valueOrNull ?? false;

    return languageAsync.when(
      data: (language) {
        if (useDynamicColor) {
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final lightTheme = lightDynamic != null
                  ? AppTheme.buildDynamicLightTheme(lightDynamic)
                  : AppTheme.lightTheme;
              final darkTheme = darkDynamic != null
                  ? (isAmoled ? AppTheme.amoledTheme : AppTheme.buildDynamicDarkTheme(darkDynamic))
                  : effectiveDarkTheme;

              return _buildMaterialApp(
                language: language,
                lightTheme: lightTheme,
                darkTheme: darkTheme,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
              );
            },
          );
        }

        return _buildMaterialApp(
          language: language,
          lightTheme: AppTheme.lightTheme,
          darkTheme: effectiveDarkTheme,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
        );
      },
      loading: () => MaterialApp(
        title: 'Aura - هالة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: effectiveDarkTheme,
        themeMode: _getThemeMode(themeMode),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => MaterialApp(
        title: 'Aura - هالة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: effectiveDarkTheme,
        themeMode: _getThemeMode(themeMode),
        home: const Scaffold(
          body: Center(child: Text('Error loading language')),
        ),
      ),
    );
  }

  MaterialApp _buildMaterialApp({
    required String language,
    required ThemeData lightTheme,
    required ThemeData darkTheme,
    required Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    required Iterable<Locale> supportedLocales,
  }) {
    return MaterialApp(
      title: 'Aura - هالة',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _getThemeMode(themeMode),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: Locale(language),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return _generateRoute(settings);
      },
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 2.0).textScaleFactor),
          ),
          child: child!,
        );
      },
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case '/signup':
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );
      case '/onboarding':
        return MaterialPageRoute(
          builder: (_) => const PreferenceScreen(),
          settings: settings,
        );
      case '/home':
        return MaterialPageRoute(
          builder: (_) => const MainWrapperScreen(),
          settings: settings,
        );
      case '/prayer':
        return MaterialPageRoute(
          builder: (_) => const PrayerScreen(),
          settings: settings,
        );
      case '/prayer_tracking':
        return MaterialPageRoute(
          builder: (_) => const PrayerTrackingScreen(),
          settings: settings,
        );
      case '/prayer_report':
        return MaterialPageRoute(
          builder: (_) => const PrayerReportScreen(),
          settings: settings,
        );
      case '/dhikr':
        return MaterialPageRoute(
          builder: (_) => const DhikrScreen(),
          settings: settings,
        );
      case '/dhikr_stats':
        return MaterialPageRoute(
          builder: (_) => const DhikrStatsScreen(),
          settings: settings,
        );
      case '/achievements':
        return MaterialPageRoute(
          builder: (_) => const AchievementsScreen(),
          settings: settings,
        );
      case '/task_form':
        return MaterialPageRoute(
          builder: (_) => TaskFormScreen(
            task: settings.arguments as Task?,
          ),
          settings: settings,
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      case '/iqama_settings':
        return MaterialPageRoute(
          builder: (_) => const IqamaSettingsScreen(),
          settings: settings,
        );
      case '/adhan_downloads':
        return MaterialPageRoute(
          builder: (_) => const AdhanDownloadsScreen(),
          settings: settings,
        );
      case '/qibla':
        return MaterialPageRoute(
          builder: (_) => const QiblaScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
