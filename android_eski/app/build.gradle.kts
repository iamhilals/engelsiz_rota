plugins {
    id("com.android.application")
    kotlin("android")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.engelsiz_rota"
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.engelsiz_rota"

        // Bu yazım şekli (property ataması) en güvenli olanıdır:
        minSdk = 21
        targetSdk = 34 
        
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BoM (Tüm Firebase paketlerinin sürümlerini birbiriyle uyumlu hale getirir)
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // Kullanmak istediğimiz servisler (Sürüm yazmamıza gerek yok, BoM hallediyor)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore") // İŞTE BU EKSİKTİ!
}

flutter {
    source = "../.."
}
