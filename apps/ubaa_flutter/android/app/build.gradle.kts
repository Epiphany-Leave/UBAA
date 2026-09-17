import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FRB may otherwise silently package a loader for libUNKNOWN.so.
val generatedBridge = rootProject.file("../../../packages/ubaa_bindings/lib/src/rust/frb_generated.dart").readText()
check(generatedBridge.contains("stem: 'ubaa_flutter_bridge'") && !generatedBridge.contains("'UNKNOWN'")) {
    "FRB library name is invalid; check Cargo metadata and regenerate bindings before building."
}

android {
    namespace = "cn.edu.ubaa.ubaa_flutter"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.edu.ubaa.ubaa_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Cargo supplies the matching Kotlin verifier; no separate downloaded version.
val cargoMetadata = providers.exec {
    workingDir(rootProject.file("../../.."))
    commandLine("cargo", "metadata", "--locked", "--offline", "--format-version", "1",
        "--filter-platform", "x86_64-linux-android")
}.standardOutput.asText.get()
val packages = (JsonSlurper().parseText(cargoMetadata) as Map<*, *>)["packages"] as List<*>
val verifier = packages.map { it as Map<*, *> }
    .single { it["name"] == "rustls-platform-verifier-android" }
repositories {
    maven {
        url = uri(File(File(verifier["manifest_path"] as String).parentFile, "maven"))
    }
}
dependencies {
    implementation("rustls:rustls-platform-verifier:0.1.1")
}
