plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // FCM (الطبقة الأولى من الإشعارات) + Play Integrity (كشف الروت والتزوير)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.hader.app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hader.app"
        minSdk = 24          // يغطي كل الهواتف المصرية المستهدفة (شاومي/ريلمي/تكنو…)
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // الرفع على Google Play بتوقيع Play App Signing
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
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

dependencies {
    // Play Integrity API — كشف الروت والمحاكيات والتطبيقات المعدلة (الجزء 4.1)
    implementation("com.google.android.play:integrity:1.4.0")
}
