# 🚀 PRODUCTION FLUTTER PROGUARD RULES
# Gavra Android v6.0.0 - ProGuard Configuration

# ===============================================
# FLUTTER CORE PROTECTION
# ===============================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keepattributes *Annotation*

# ===============================================
# SUPABASE & DATABASE PROTECTION
# ===============================================
# Keep Supabase core classes
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**

# PostgreSQL driver protection
-keep class org.postgresql.** { *; }
-dontwarn org.postgresql.**

# Database model classes (Gavra specific)
-keep class * extends java.lang.Object {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ===============================================
# FIREBASE SERVICES PROTECTION
# ===============================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging
# Keep Firebase messaging related classes
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ===============================================
# ANDROID PERMISSIONS & LOCATION
# ===============================================
# Geolocator plugin protection
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Permission handler protection
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ===============================================
# AUDIO & MEDIA SERVICES
# ===============================================
# Just Audio plugin protection
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# Audio session management
-keep class com.ryanheise.audio_session.** { *; }

# ===============================================
# FILE & STORAGE OPERATIONS
# ===============================================
# Path provider protection
-keep class io.flutter.plugins.pathprovider.** { *; }

# File picker and storage
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ===============================================
# NETWORKING & CONNECTIVITY
# ===============================================
# Connectivity plus protection
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Network state monitoring
-keep class io.flutter.plugins.connectivity.** { *; }

# ===============================================
# UI & NOTIFICATION PLUGINS
# ===============================================
# Local notifications protection
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keyboard visibility
-keep class io.flutter.plugins.flutter_keyboard_visibility.** { *; }

# ===============================================
# SECURITY & OBFUSCATION SETTINGS
# ===============================================
# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable

# Rename source file attribute to hide original source
-renamesourcefileattribute SourceFile

# Remove logging in production
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ===============================================
# OPTIMIZATION SETTINGS
# ===============================================
# Aggressive optimizations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# ===============================================
# GOOGLE PLAY CORE PROTECTION (R8 Fix)
# ===============================================
# Fix for missing Google Play Core classes in R8
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter Play Store Split Application
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Play Store split install components
-keep class * implements com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }

# ===============================================
# GAVRA SPECIFIC PROTECTION
# ===============================================
# Protect custom service classes
-keep class ** extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Keep method names for Supabase RPC calls
-keepclassmembernames class * {
    @com.google.gson.annotations.SerializedName <methods>;
}

# Protect enum values used in database
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ===============================================
# PERFORMANCE OPTIMIZATIONS
# ===============================================
# Remove debug information
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
    static void checkExpressionValueIsNotNull(java.lang.Object, java.lang.String);
}

# Optimize string operations
-optimizations !code/simplification/string

# ===============================================
# HUAWEI HMS & AGCONNECT (2026-01-05)
# ===============================================
-keep class com.huawei.hms.** { *; }
-keep class com.huawei.agconnect.** { *; }
-keep class com.huawei.hianalytics.** { *; }
-keep class com.huawei.updatesdk.** { *; }
-keep class com.huawei.hmf.** { *; }
-dontwarn com.huawei.**

# Huawei Push Kit
-keep class com.huawei.hms.push.** { *; }
-keep public class * extends com.huawei.hms.push.HmsMessageService { *; }

# ===============================================
# FREEZED & JSON SERIALIZATION (2026-01-05)
# ===============================================
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Freezed generated classes
-keep class **.*Freezed* { *; }
-keep class **.*_$* { *; }

# ===============================================
# GRAPHQL (2026-01-05)
# ===============================================
-keep class com.apollographql.** { *; }
-dontwarn com.apollographql.**

# GraphQL Flutter
-keep class graphql.** { *; }
-dontwarn graphql.**

# ===============================================
# BIOMETRIC / LOCAL AUTH (2026-01-05)
# ===============================================
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# ===============================================
# VIBRATION PLUGIN (2026-01-05)
# ===============================================
-keep class com.benjaminabel.vibration.** { *; }

# Final message
# Configuration optimized for Gavra Android v6.0.0
# Balances security, performance, and functionality
# Updated 2026-01-05: Added Huawei, Freezed, GraphQL, Biometric rules