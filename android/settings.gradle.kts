pluginManagement {
    val properties = java.util.Properties()
    // Read with UTF-8 so Chinese SDK paths are decoded correctly.
    file("local.properties").bufferedReader(Charsets.UTF_8).use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
    require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }

    // Workaround: Gradle's Kotlin DSL script-loader and the Flutter Gradle plugin both
    // read local.properties with ISO-8859-1 (Java default), which garbles non-ASCII
    // SDK paths on Windows.  When the ASCII junction C:\flutter_sdk exists we rewrite
    // local.properties to use that path so both loaders see only ASCII characters.
    val junctionSdk = "C:\\flutter_sdk"
    val safeSdkPath = if (java.io.File("$junctionSdk\\packages\\flutter_tools\\gradle").exists()) {
        properties.setProperty("flutter.sdk", junctionSdk)
        file("local.properties").bufferedWriter(Charsets.ISO_8859_1).use {
            properties.store(it, null)
        }
        junctionSdk
    } else {
        flutterSdkPath
    }

    includeBuild("$safeSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
