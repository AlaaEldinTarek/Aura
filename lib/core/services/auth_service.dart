import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show HttpServer, InternetAddress, Platform;
import 'dart:math';
import 'google_oauth_config.dart';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Auth State Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Get User ID
  String? get userId => currentUser?.uid;

  // Get User Email
  String? get userEmail => currentUser?.email;

  // Get User Display Name
  String? get userDisplayName => currentUser?.displayName;

  // Get User Photo URL
  String? get userPhotoUrl => currentUser?.photoURL;

  // Sign In with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw Exception('Unknown error occurred');
    }
  }

  // Sign Up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw Exception('Unknown error occurred');
    }
  }

  // Sign In with Google
  Future<UserCredential> signInWithGoogle() async {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) return _signInWithGoogleDesktop();

    try {
      developer.log('🔐 [GOOGLE_SIGN_IN] Starting Google Sign-In flow...', name: 'AuthService');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log('🔐 [GOOGLE_SIGN_IN] User cancelled sign-in', name: 'AuthService');
        throw Exception('Google sign in was cancelled');
      }

      developer.log('🔐 [GOOGLE_SIGN_IN] Got Google account: ${googleUser.email}', name: 'AuthService');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      developer.log('🔐 [GOOGLE_SIGN_IN] Got access token: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}', name: 'AuthService');

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        developer.log('🔐 [GOOGLE_SIGN_IN] ERROR: Both tokens are null!', name: 'AuthService');
        throw Exception('Failed to get Google authentication tokens. Please check your internet connection and try again.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      developer.log('🔐 [GOOGLE_SIGN_IN] Firebase sign-in successful: ${userCredential.user?.uid}', name: 'AuthService');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log('🔐 [GOOGLE_SIGN_IN] FirebaseAuthException: ${e.code} - ${e.message}', name: 'AuthService');
      throw _getErrorMessage(e);
    } catch (e, st) {
      developer.log('🔐 [GOOGLE_SIGN_IN] Error: $e\n$st', name: 'AuthService');
      rethrow;
    }
  }

  // ─── Desktop Google OAuth (PKCE + local server) ───────────────────────────

  static const _googleClientId = kGoogleDesktopClientId;
  static const _googleClientSecret = kGoogleDesktopClientSecret;

  Future<UserCredential> _signInWithGoogleDesktop() async {
    developer.log('🔐 [GOOGLE_DESKTOP] Starting PKCE OAuth flow', name: 'AuthService');

    final verifier = _generateCodeVerifier();
    final challenge = _computeCodeChallenge(verifier);
    final port = await _findFreePort();
    final redirectUri = 'http://127.0.0.1:$port';

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _googleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    developer.log('🔐 [GOOGLE_DESKTOP] Listening on $redirectUri', name: 'AuthService');

    await launchUrl(authUri, mode: LaunchMode.externalApplication);
    developer.log('🔐 [GOOGLE_DESKTOP] Browser opened', name: 'AuthService');

    String? code;
    String? oauthError;
    await for (final request in server) {
      code = request.uri.queryParameters['code'];
      oauthError = request.uri.queryParameters['error'];
      final success = code != null;
      final html = success
          ? '<html><body style="font-family:sans-serif;text-align:center;padding:60px">'
              '<h2 style="color:#4CAF50">✅ Signed in successfully!</h2>'
              '<p>You can close this tab and return to Aura.</p></body></html>'
          : '<html><body style="font-family:sans-serif;text-align:center;padding:60px">'
              '<h2 style="color:#F44336">❌ Sign-in failed</h2>'
              '<p>$oauthError</p></body></html>';
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write(html);
      await request.response.close();
      break;
    }
    await server.close();

    if (code == null) {
      throw Exception('Google sign-in was cancelled or failed: $oauthError');
    }

    developer.log('🔐 [GOOGLE_DESKTOP] Got auth code, exchanging for tokens', name: 'AuthService');

    final tokenResponse = await Dio().post<Map<String, dynamic>>(
      'https://oauth2.googleapis.com/token',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.json,
      ),
      data: {
        'code': code,
        'client_id': _googleClientId,
        'client_secret': _googleClientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    );

    final idToken = tokenResponse.data?['id_token'] as String?;
    final accessToken = tokenResponse.data?['access_token'] as String?;

    if (idToken == null) {
      throw Exception('Failed to get ID token from Google');
    }

    developer.log('🔐 [GOOGLE_DESKTOP] Got tokens, signing into Firebase', name: 'AuthService');

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    developer.log('🔐 [GOOGLE_DESKTOP] Firebase sign-in successful: ${userCredential.user?.uid}', name: 'AuthService');
    return userCredential;
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _computeCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<int> _findFreePort() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again before deleting your account');
      }
      throw Exception('Failed to delete account: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Update Password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again before updating your password');
      }
      throw Exception('Failed to update password: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // Reload User
  Future<void> reload() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Failed to reload user: $e');
    }
  }

  // Error Message Handler
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'Invalid credentials.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
