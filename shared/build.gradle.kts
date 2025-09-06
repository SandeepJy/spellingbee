plugins {
    kotlin("multiplatform")
    kotlin("native.cocoapods")
    kotlin("plugin.serialization")
}

version = "1.0"

kotlin {
    iosX64()
    iosArm64()
    iosSimulatorArm64()

    cocoapods {
        summary = "Shared Module for iOS and Android"
        homepage = "https://github.com/yourproject"
        ios.deploymentTarget = "14.0"
        
        framework {
            baseName = "shared"
            isStatic = true
        }
        
        // This is crucial - it tells CocoaPods where to find the framework
        podfile = project.file("../Podfile")
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")
                
                // Firebase KMP libraries
                implementation("dev.gitlive:firebase-auth:1.10.4")
                implementation("dev.gitlive:firebase-firestore:1.10.4")
                implementation("dev.gitlive:firebase-storage:1.10.4")
                implementation("dev.gitlive:firebase-common:1.10.4")
            }
        }

        val iosX64Main by getting
        val iosArm64Main by getting
        val iosSimulatorArm64Main by getting
        
        val iosMain by creating {
            dependsOn(commonMain)
            iosX64Main.dependsOn(this)
            iosArm64Main.dependsOn(this)
            iosSimulatorArm64Main.dependsOn(this)
        }
    }
}