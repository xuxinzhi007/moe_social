plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.moe_social"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // 配置签名
    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")?.takeIf { it.isNotBlank() }
            keyAlias = "key"
            keyPassword = System.getenv("KEY_PASSWORD")?.takeIf { it.isNotBlank() }
        }
    }

    defaultConfig {
        applicationId = "com.example.moe_social"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 真机常用 ABI；跳过 x86_64 可避开 Agora iris_method_channel 在模拟器 ABI 上的 CMake 问题并缩短编译
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        debug {
            // 本地开发包与正式包共存，避免签名冲突导致覆盖失败。
            applicationIdSuffix = ".dev"
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

val validateReleaseSigningCredentials = tasks.register("validateReleaseSigningCredentials") {
    doLast {
        val missing = listOf("KEYSTORE_PASSWORD", "KEY_PASSWORD")
            .filter { System.getenv(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException("Release signing requires non-blank environment variables: ${missing.joinToString()}")
        }
    }
}

tasks.matching {
    name in listOf("validateSigningRelease", "packageRelease", "signReleaseBundle")
}.configureEach {
    dependsOn(validateReleaseSigningCredentials)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
