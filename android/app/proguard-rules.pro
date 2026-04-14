# Fix for flutter_local_notifications TypeToken error with R8 code shrinking
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep flutter_local_notifications models
-keep class com.dexterous.flutterlocalnotifications.** { *; }
