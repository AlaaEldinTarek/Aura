import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/shared_preferences_service.dart';
import '../models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firestore Service Provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService.instance;
});

// Shared Preferences Service Provider
final sharedPreferencesServiceProvider =
    Provider<SharedPreferencesService>((ref) {
  return SharedPreferencesService.instance;
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Auth State Notifier
class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final SharedPreferencesService _prefsService;

  AuthStateNotifier(
    this._authService,
    this._firestoreService,
    this._prefsService,
  ) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      final user = _authService.currentUser;
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Sync user data with Firestore and local preferences
  Future<void> _syncUserData(User user) async {
    try {
      final uid = user.uid;

      // Check if this was a guest session before signing in
      final wasGuest = await _prefsService.isGuest();

      // Check if user exists in Firestore with timeout
      final exists = await _firestoreService.userExists(uid).timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (exists) {
        debugPrint('📥 Returning user found - syncing Firestore data to local');

        // Load from Firestore and sync to local with timeout
        final userData = await _firestoreService.getUserData(uid).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (userData != null) {
          await _syncToLocal(userData);
        }
      } else {
        // New user or guest converting to account
        debugPrint('🆕 New user account - migrating local preferences to Firestore');

        // Load current local settings (from guest session or defaults)
        final themeMode = await _prefsService.getThemeMode();
        final language = await _prefsService.getLanguage();

        debugPrint('📦 Migrating preferences: theme=$themeMode, language=$language');

        // Create new user in Firestore with current local settings
        final userData = UserData.create(
          uid: uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );

        // Apply local preferences to new user
        final userWithSettings = userData.copyWith(
          themeMode: themeMode,
          language: language,
        );

        // Try to create user data with timeout - fail gracefully if unavailable
        try {
          await _firestoreService.createUserData(userWithSettings).timeout(
            const Duration(seconds: 5),
          );
          debugPrint('✅ Firestore user data created with migrated preferences');
        } catch (e, st) {
          // Firestore not set up or unavailable - continue with local only
          debugPrint('⚠️ Firestore user data creation failed: $e');
          debugPrint('📍 Continuing with local storage only');
        }
      }

      // Clear guest mode flag after successful sign-in
      if (wasGuest) {
        await _prefsService.setGuest(false);
        debugPrint('✅ Guest mode cleared - user now signed in');
      }
    } catch (e, st) {
      // Log sync errors but allow login to succeed
      debugPrint('⚠️ Firestore sync failed: $e');
      debugPrint('📍 Stack trace: $st');
    }
  }

  // Sync Firestore data to local preferences
  Future<void> _syncToLocal(UserData userData) async {
    try {
      await _prefsService.setThemeMode(userData.themeMode);
      await _prefsService.setLanguage(userData.language);
      debugPrint('✅ Local sync completed successfully');
    } catch (e, st) {
      debugPrint('⚠️ Local sync partially failed: $e');
      debugPrint('📍 Stack trace: $st');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        await _syncUserData(user);
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      final user = userCredential.user;
      if (user != null) {
        await _syncUserData(user);
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signInWithGoogle();
      final user = userCredential.user;
      if (user != null) {
        await _syncUserData(user);
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Auth State Notifier Provider
final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return AuthStateNotifier(authService, firestoreService, prefsService);
});

// Is Logged In Provider
final isLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final value = authState.value;
  return value != null;
});

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value;
});
