allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // 🚀 OneSignal Dependency Resolution Strategy
    configurations.all {
        resolutionStrategy {
            // Force specific versions for OneSignal compatibility
            force("com.google.firebase:firebase-messaging:23.4.0")
            force("androidx.work:work-runtime:2.8.1")
            force("androidx.cardview:cardview:1.0.0")
            force("androidx.browser:browser:1.3.0")
        }
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
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
