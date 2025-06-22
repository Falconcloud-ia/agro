import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // 🔹 Plugin de Firebase
}

// 🔐 Cargar propiedades de la firma desde key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.controlgestionagro"
    compileSdk = 35
    ndkVersion = "27.0.12077973" // ✅ NDK actualizado

    defaultConfig {
        applicationId = "com.example.ensayotratamientoagro"
        minSdk = 23 // ✅ SDK mínimo compatible con Firebase Auth
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}


afterEvaluate {
    tasks.named("assembleRelease") {
        doLast {
            val apkSrc = file("$buildDir/outputs/apk/release/app-release.apk")
            val apkDstDir = file("$buildDir/outputs/flutter-apk")
            apkDstDir.mkdirs()
            val apkDst = File(apkDstDir, "app-release.apk")
            if (apkSrc.exists()) {
                apkSrc.copyTo(apkDst, overwrite = true)
                println("✅ APK copiado a: ${apkDst.absolutePath}")
            } else {
                println("⚠️ APK no encontrado en: ${apkSrc.absolutePath}")
            }
        }
    }
}


flutter {
    source = "../.."
}
