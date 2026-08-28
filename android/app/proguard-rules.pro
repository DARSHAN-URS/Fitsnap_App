# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep application native classes
-keep class com.sabtrack.ai.** { *; }

# Google Sign In & Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Health Connect
-keep class androidx.health.** { *; }
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.**
