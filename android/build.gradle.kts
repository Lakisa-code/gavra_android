allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Dependency resolution strategy preserved for historical reasons; ensure Firebase Messaging remains compatible.
    configurations.all {
        resolutionStrategy {
            // Force Firebase messaging to a compatible version
            force("com.google.firebase:firebase-messaging:23.4.0")
        }
    }
}

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
