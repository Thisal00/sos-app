import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.sos"
    compileSdk = 35 // 🔥 අලුත්ම API 35
    
    ndkVersion = "27.0.12077973" // 🔥 අලුත් Packages වලට හරියන NDK එක

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.sos"
        minSdk = flutter.minSdkVersion 
        targetSdk = 35 // 🔥 මේකත් අනිවාර්යයෙන් 35
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.core:core:1.13.1")
        
        // 🔥 THE ULTIMATE BYPASS: ඕනෑම පැකේජ් එකකින් WorkManager ඉල්ලුවොත් 2.9.1 ම දෙන්න කියලා බල කරනවා
        force("androidx.work:work-runtime:2.9.1")
        force("androidx.work:work-runtime-ktx:2.9.1")
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    // 🔥 Desugaring Library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 🚀 THE ULTIMATE LOCK: 2.10.2 එන එක සම්පූර්ණයෙන්ම බ්ලොක් කරලා 2.9.1 ට හිර කිරීම!
    implementation("androidx.work:work-runtime") {
        version {
            strictly("2.9.1")
        }
    }
    implementation("androidx.work:work-runtime-ktx") {
        version {
            strictly("2.9.1")
        }
    }
}