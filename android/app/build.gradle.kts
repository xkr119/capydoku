import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 업로드 키. **저장소에 넣지 않는다** — android/key.properties는 .gitignore에
// 걸려 있고, 파일이 없으면 아래에서 디버그 키로 떨어진다. 그래야 키스토어가
// 없는 PC(CI, 다른 작업 PC)에서도 `flutter run --release`가 그냥 된다.
// 실제 업로드용 AAB는 키가 있는 PC에서만 만들어진다.
// 만드는 법은 android/key.properties.example 참고.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "kr.tak.capydoku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어에서 앱을 식별하는 값. **한 번 올리면 영원히 못 바꾼다.**
        applicationId = "kr.tak.capydoku"
        // 버전은 pubspec.yaml의 `version:` 한 줄에서 온다(예: 1.0.0+1).
        // 재업로드할 때마다 빌드 번호(+뒤)를 올려야 Play가 받아 준다.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasUploadKey) "upload" else "debug",
            )

            // R8이 리플렉션 대상(WorkManager 등, 광고 SDK가 유발)을 지우면
            // 시작 즉시 죽는다 — photo_tidy·nemologic에서 겪은 사고.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
