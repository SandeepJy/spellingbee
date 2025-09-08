plugins {
    // Suppress warnings about applying plugins
    kotlin("multiplatform") version "1.9.20" apply false
    kotlin("plugin.serialization") version "1.9.20" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}