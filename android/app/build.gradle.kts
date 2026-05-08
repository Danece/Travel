import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── 簽名設定：從 android/key.properties 讀取（不進 git） ──────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.travelmark.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"]     as? String ?: ""
            keyPassword  = keystoreProperties["keyPassword"]  as? String ?: ""
            storeFile    = (keystoreProperties["storeFile"]   as? String)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as? String ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.travelmark.app"
        minSdk        = 26
        targetSdk     = 34
        versionCode   = 3
        versionName   = "1.0.0"
    }

    buildTypes {
        release {
            // 使用 key.properties 中的 release 簽名金鑰
            signingConfig    = signingConfigs.getByName("release")
            isMinifyEnabled  = true    // R8 程式碼壓縮
            isShrinkResources = true   // 移除未使用的資源
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
