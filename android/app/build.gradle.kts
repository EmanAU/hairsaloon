plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.barbershop.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.barbershop.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ❌ IMPORTANT: NO abiFilters here (avoid conflict with split-per-abi)
    }

    flavorDimensions += "audience"
    productFlavors {
        create("business") {
            dimension = "audience"
            resValue("string", "app_name", "TrimMatrix Business")
        }
        create("customer") {
            dimension = "audience"
            applicationIdSuffix = ".customer"
            resValue("string", "app_name", "TrimMatrix Customer")
        }
    }

    buildTypes {
        release {
            // Temporary (testing only)
            signingConfig = signingConfigs.getByName("debug")

            // Optional optimizations
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ✅ (Optional but safe) packaging fix for native libs
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}
