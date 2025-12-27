import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Apply AGConnect as a plugin via buildscript classpath
apply(plugin = "com.huawei.agconnect")

// 🔐 PRODUCTION KEYSTORE CONFIGURATION
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 📦 Load local.properties for version info (CI writes flutter.versionCode here)
val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

// Helper function to get versionCode as Int (handles both String and Int types)
fun getFlutterVersionCode(): Int {
    val versionCodeFromProps = localProperties.getProperty("flutter.versionCode")
    if (versionCodeFromProps != null) {
        return versionCodeFromProps.toIntOrNull() ?: 1
    }
    return 1
}

fun getFlutterVersionName(): String {
    return localProperties.getProperty("flutter.versionName") ?: "1.0.0"
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // Add Firebase Cloud Messaging
    implementation("com.google.firebase:firebase-messaging")

    // 🚀 OneSignal Dependency Resolution - Force compatible versions
    implementation("androidx.work:work-runtime:2.8.1") {
        because("OneSignal requires work-runtime")
    }
    implementation("androidx.cardview:cardview:1.0.0") {
        because("OneSignal in-app-messages requires cardview")
    }
    implementation("androidx.browser:browser:1.3.0") {
        because("OneSignal in-app-messages requires browser")
    }

    // Force Firebase messaging version for OneSignal compatibility
    implementation("com.google.firebase:firebase-messaging:23.4.0") {
        because("OneSignal requires firebase-messaging [21.0.0, 23.4.99]")
    }

    // 🚀 Google Play Core for production features (R8 fix)
    implementation("com.google.android.play:core:1.10.3") {
        because("Required for Flutter Play Store integration and R8 compatibility")
    }
}

flutter {
    source = "../.."
}

android {
    namespace = "com.gavra013.gavra_android"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    packaging {
        jniLibs.pickFirsts.add("**/libc++_shared.so")
        jniLibs.pickFirsts.add("**/libjsc.so")
    }

    defaultConfig {
        applicationId = "com.gavra013.gavra_android"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = getFlutterVersionCode()
        versionName = getFlutterVersionName()
        multiDexEnabled = true
    }

    // 🔐 PRODUCTION SIGNING CONFIGURATION
    signingConfigs {
        create("release") {
            if (keystoreProperties.containsKey("keyAlias")) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        named("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
