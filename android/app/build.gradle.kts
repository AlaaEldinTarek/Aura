plugins {
    id("com.android.application")
    id("kotlin-android")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aura.hala"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aura.hala"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Firebase dependencies
dependencies {
    // AndroidX AppCompat for AppCompatActivity
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Media session for catching volume keys on lock screen
    implementation("androidx.media:media:1.7.0")

    // Import the Firebase BoM (Bill of Materials)
    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))

    // Firebase Auth
    implementation("com.google.firebase:firebase-auth")

    // Firebase Cloud Messaging for push notifications
    implementation("com.google.firebase:firebase-messaging")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.3.0")

    // WorkManager for background tasks (3rd layer protection for countdown notification)
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Core library desugaring for notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
