import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

val packageId = "com.xoropower.app"
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested && !signingPropertiesFile.exists()) {
    throw GradleException(
        "Create android/key.properties with the release keystore credentials before building a release.",
    )
}
val missingSigningProperties = listOf(
    "storeFile",
    "keyAlias",
    "storePassword",
    "keyPassword",
).filter { signingProperties.getProperty(it).isNullOrBlank() }
if (releaseRequested && missingSigningProperties.isNotEmpty()) {
    throw GradleException(
        "Set all required signing values in android/key.properties before building a release.",
    )
}
val configuredStoreFile = signingProperties.getProperty("storeFile")
if (releaseRequested &&
    (configuredStoreFile.isNullOrBlank() ||
        !rootProject.file(configuredStoreFile).isFile)
) {
    throw GradleException("The release keystore configured in android/key.properties was not found.")
}

android {
    namespace = packageId
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = packageId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = signingProperties["keyAlias"] as String?
            keyPassword = signingProperties["keyPassword"] as String?
            storeFile = (signingProperties["storeFile"] as String?)?.let {
                rootProject.file(it)
            }
            storePassword = signingProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
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
