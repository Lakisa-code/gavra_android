import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// The AGC plugin was causing resolution failures in some environments. For local debug runs we
// don't need to apply the AGC Gradle plugin — it's used mainly for release / AGC-specific tasks.
// If you need AGC plugin locally, uncomment the line below after ensuring the plugin artifact
// is available in the configured repositories or your environment.
// apply(plugin = "com.huawei.agconnect")

// 🔐 PRODUCTION KEYSTORE CONFIGURATION
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gavra013.gavra_android"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    packaging {
        jniLibs.pickFirsts.add("**/libc++_shared.so")
        jniLibs.pickFirsts.add("**/libjsc.so")
    }

    defaultConfig {
        applicationId = "com.gavra013.gavra_android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        
        // 🎮 XIAOMI GAMING OPTIMIZACIJE - Flutter handles ABI filtering automatically
        versionCode = 1
        versionName = "6.0.0"
        
        // 🔧 Multidex support for large APKs
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
        release {
            // 🚀 PRODUCTION OPTIMIZATIONS - Temporarily disabled minification for debugging
            isMinifyEnabled = false
            isShrinkResources = false
            
            // ProGuard configuration for code obfuscation
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // 🔐 Production signing configuration
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🔧 Multidex support
    implementation("androidx.multidex:multidex:2.0.1")

    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // Huawei HMS
    implementation(platform("com.huawei.hms:push:6.13.0.300"))

    // 🚀 Dependency Resolution - ensure versions for required Android libraries
    implementation("androidx.work:work-runtime:2.8.1")
    implementation("androidx.cardview:cardview:1.0.0")
    implementation("androidx.browser:browser:1.3.0")

    // Force Firebase messaging to a known-good version
    implementation("com.google.firebase:firebase-messaging:23.4.0")

    // 🚀 Google Play Core - Resolved dependency conflict
    configurations.all {
        resolutionStrategy {
            // Force all Google Play Core dependencies to use the same version
            force("com.google.android.play:core-common:2.0.3")
            force("com.google.android.play:feature-delivery:2.1.0")
            // Completely exclude the conflicting old version
            exclude(group = "com.google.android.play", module = "core")
        }
        // Exclude all transitive dependencies of the old core library
        exclude(group = "com.google.android.play", module = "core")
    }
}

flutter {
    source = "../.."
}
