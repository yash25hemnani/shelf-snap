import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, from android/key.properties (kept out of git).
// Every update must use the same key, or phones refuse to install it.
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) keyPropsFile.inputStream().use { keyProps.load(it) }

android {
    namespace = "com.example.shelf_snap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // The app's identity on phones and in Firebase. Changing it makes a
        // different app, so friends would have to reinstall.
        applicationId = "com.yashhemnani.shelfsnap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProps["keyAlias"] as String?
            keyPassword = keyProps["keyPassword"] as String?
            storeFile = (keyProps["storeFile"] as String?)?.let { file(it) }
            storePassword = keyProps["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Falls back to the debug key on a machine without key.properties
            signingConfig = if (keyProps.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
