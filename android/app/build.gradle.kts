import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpMajorVersion >= 9 &&
        (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
if (!isBuiltInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.pilinara"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.pilinara"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Rust native library ABI filters
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }
    }

    packagingOptions {
        jniLibs.useLegacyPackaging = true
        // Exclude unnecessary native libraries
        excludes += listOf("META-INF/**", "**.so.old")
    }

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val config = keyProperties.getProperty("storeFile")?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        all {
            if (!project.hasProperty("unsigned")) {
                signingConfig = config ?: signingConfigs["debug"]
            }
        }
        release {
            if (project.hasProperty("dev")) {
                applicationIdSuffix = ".dev"
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliPlus dev",
                )
            }
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
        }
    }

    // Rust build integration
    preBuild {
        dependsOn("cargoBuildDebug")
    }
    
    tasks.register<Exec>("cargoBuildDebug") {
        group = "build"
        description = "Build Rust native library for debug"
        
        val ndkHome = System.getenv("ANDROID_NDK_HOME") ?: findNdkHome()
        val abiFilters = android.defaultConfig.ndk.abiFilters
        
        for (abi in abiFilters) {
            val target = when (abi) {
                "arm64-v8a" -> "aarch64-linux-android"
                "armeabi-v7a" -> "armv7-linux-androideabi"
                "x86_64" -> "x86_64-linux-android"
                "x86" -> "i686-linux-android"
                else -> null
            } ?: continue
            
            val outputDir = file("$buildDir/intermediates/rust/debug/$abi")
            outputs.dir(outputDir)
            
            doLast {
                outputDir.mkdirs()
                
                val toolchainBin = file("$ndkHome/toolchains/llvm/prebuilt/linux-x86_64/bin")
                val clang = file("$toolchainBin/${target}${defaultConfig.minSdkVersion}-clang")
                
                if (!clang.exists()) {
                    logger.warn("Clang not found for $abi at ${clang.path}, skipping")
                    return@doLast
                }
                
                val cargoEnv = mapOf(
                    "CC" to clang.absolutePath,
                    "CXX" to file("$toolchainBin/${target}-clang++").absolutePath,
                    "AR" to file("$toolchainBin/llvm-ar").absolutePath,
                    "TARGET" to target,
                    "ANDROID_NDK_HOME" to ndkHome,
                    "CARGO_TARGET_DIR" to file("$buildDir/rust-target").absolutePath
                )
                
                exec {
                    commandLine("cargo", "build", "--target", target, "--debug")
                    workingDir = file("${project.rootDir}/../rust")
                    environment(cargoEnv)
                }
                
                // Copy .so to jniLibs
                val soSrc = file("${buildDir}/rust-target/${target}/debug/libpilinara_native.so")
                val soDest = file("$outputDir/libpilinara_native.so")
                if (soSrc.exists()) {
                    soSrc.copyTo(soDest, overwrite = true)
                }
            }
        }
    }
    
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs(arrayOf("src/main/jniLibs"))
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

fun findNdkHome(): String {
    val localProps = file("local.properties")
    if (localProps.exists()) {
        val props = Properties()
        localProps.inputStream().use { props.load(it) }
        val sdkHome = props.getProperty("sdk.dir")
        if (sdkHome != null) {
            val ndkPaths = listOf(
                "$sdkHome/ndk/${android.ndkVersion}",
                "$sdkHome/ndk/bundle",
                "$sdkHome/ndk/latest"
            )
            for (path in ndkPaths) {
                if (file(path).exists()) return path
            }
        }
    }
    return System.getenv("ANDROID_NDK_HOME") ?: ""
}
