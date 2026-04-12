// File: lib/core/services/firebase_options.dart
//
// Firebase Configuration for Aura App
//
// Project: com-aura-hala
// Package: com.aura.hala

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Default Firebase options for the Aura app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      case TargetPlatform.iOS:
        return ios;

      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// ANDROID CONFIGURATION
  /// Project: com-aura-hala
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_tzdYWMrxYIHVtEmZ0YxCxOX5rfb0_BA',
    appId: '1:101079644290:android:c817d6084a5fb73a025c9b',
    messagingSenderId: '101079644290',
    projectId: 'com-aura-hala',
    storageBucket: 'com-aura-hala.firebasestorage.app',
  );

  /// IOS CONFIGURATION
  /// TODO: Add iOS app in Firebase Console and update these values
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '101079644290',
    projectId: 'com-aura-hala',
    storageBucket: 'com-aura-hala.firebasestorage.app',
  );
}
