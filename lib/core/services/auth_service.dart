import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    try {
      // Trigger the authentication flow
      developer.log('🔐 [GOOGLE_SIGN_IN] Starting Google Sign-In flow...', name: 'AuthService');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log('🔐 [GOOGLE_SIGN_IN] User cancelled sign-in', name: 'AuthService');
        throw Exception('Google sign in was cancelled');
      }

      developer.log('🔐 [GOOGLE_SIGN_IN] Got Google account: ${googleUser.email}', name: 'AuthService');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      developer.log('🔐 [GOOGLE_SIGN_IN] Got access token: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}', name: 'AuthService');

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        developer.log('🔐 [GOOGLE_SIGN_IN] ERROR: Both tokens are null!', name: 'AuthService');
        throw Exception('Failed to get Google authentication tokens. Please check your internet connection and try again.');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
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
