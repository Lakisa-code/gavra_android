buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
    dependencies {
        classpath("com.huawei.agconnect:agcp:1.6.5.300")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
    
    // Dependency resolution strategy preserved for historical reasons; ensure Firebase Messaging remains compatible.
    configurations.all {
        resolutionStrategy {
            // Force Firebase messaging to a compatible version
            force("com.google.firebase:firebase-messaging:23.4.0")
        }
    }
}

// NOTE: We avoid forcing the AGC plugin across the root project because some dev environments
// cannot resolve the AGC plugin artifact. Module-level AGC usage can be enabled per-developer
// when needed by adding the plugin locally or enabling a CI-only configuration.

plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
