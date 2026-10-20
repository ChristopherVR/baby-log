import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val ciKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
// Play credentials are separate from the existing GitHub APK key. Never fall
// back to debug signing for a Play release.
val playSigning = Properties().apply {
    val source = rootProject.file("play-signing.properties")
    if (source.isFile) source.inputStream().use { load(it) }
}
fun playCredential(environment: String, property: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: playSigning.getProperty(property)?.takeIf { it.isNotBlank() }
val playStoreFile = playCredential("PLAY_UPLOAD_KEYSTORE_PATH", "storeFile")
val playStorePassword = playCredential("PLAY_UPLOAD_STORE_PASSWORD", "storePassword")
val playKeyAlias = playCredential("PLAY_UPLOAD_KEY_ALIAS", "keyAlias")
val playKeyPassword = playCredential("PLAY_UPLOAD_KEY_PASSWORD", "keyPassword")

android {
    namespace = "com.babyapp.baby_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this ID for both channels; GitHub updates must retain their identity.
        applicationId = "com.babyapp.baby_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("playUpload") {
            storeFile = playStoreFile?.let { rootProject.file(it) }
            storePassword = playStorePassword
            keyAlias = playKeyAlias
            keyPassword = playKeyPassword
        }
        if (ciKeystorePath != null) {
            create("ci") {
                storeFile = file(ciKeystorePath)
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("github") {
            dimension = "distribution"
            // Preserve the key used by existing sideloaded installations.
            signingConfig = signingConfigs.getByName(if (ciKeystorePath != null) "ci" else "debug")
        }
        create("play") {
            dimension = "distribution"
            signingConfig = signingConfigs.getByName("playUpload")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Check the actual task graph, including aggregate release tasks, before any
// compilation. A missing Play key must never produce a debug-signed bundle.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.path.startsWith(":app:") && it.name.contains("PlayRelease") }) {
        require(listOf(playStoreFile, playStorePassword, playKeyAlias, playKeyPassword).all { !it.isNullOrBlank() }) {
            "Play release signing is missing. Set PLAY_UPLOAD_KEYSTORE_PATH, PLAY_UPLOAD_STORE_PASSWORD, " +
                "PLAY_UPLOAD_KEY_ALIAS and PLAY_UPLOAD_KEY_PASSWORD, or android/play-signing.properties."
        }
        require(rootProject.file(playStoreFile!!).isFile) { "Play upload keystore does not exist." }
    }
}
