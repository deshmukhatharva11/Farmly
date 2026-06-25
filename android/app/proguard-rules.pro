# Flutter/Dart ProGuard rules
# Keep Flutter entry point
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# OkHttp (used by http package)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep JSON parsing models
-keepattributes Signature
-keepattributes *Annotation*
