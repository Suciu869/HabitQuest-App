import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.samuel.habitquest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // <-- SINTAXA CORECTĂ PENTRU KOTLIN
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

   defaultConfig {
        applicationId = "com.samuel.habitquest"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // REVENIM LA VARIABILELE AUTOMATE:
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            
            // O metodă mult mai sigură pentru Kotlin de a citi calea fișierului
            val keystoreFilePath = keystoreProperties.getProperty("storeFile")
            if (keystoreFilePath != null) {
                storeFile = file(keystoreFilePath)
            }
            
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            // Alte lucruri care mai sunt pe aici (ex: isMinifyEnabled, etc)
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // <-- Am schimbat din 2.0.4 in 2.1.4
}

flutter {
    source = "../.."
}