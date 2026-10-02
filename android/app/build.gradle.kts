import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.util.Properties
import org.apache.tools.ant.taskdefs.condition.Os

plugins {
    id("com.android.application")
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
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.pilinara"
        minSdk = 21
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
        
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
        
        // Rust native library
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    packagingOptions {
        jniLibs.useLegacyPackaging = true
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
                    value = "PiliNara dev",
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
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode
        }
    }
    
    // Rust build task
    val rustTargetDir = layout.buildDirectory.dir("rust-target")
    
    tasks.register<Exec>("cargoBuildRust") {
        group = "rust"
        description = "Build Rust native library for Android"
        
        val ndkHome = android.ndkDirectory.absolutePath
        val toolchain = "$ndkHome/toolchains/llvm/prebuilt/linux-x86_64/bin"
        
        val targets = mapOf(
            "arm64-v8a" to "aarch64-linux-android21"
        )
        
        for ((abi, target) in targets) {
            doLast {
                val env = mutableMapOf<String, String>()
                env["CC"] = "$toolchain/$target-clang"
                env["CXX"] = "$toolchain/$target-clang++"
                env["AR"] = "$toolchain/llvm-ar"
                env["CARGO_TARGET_DIR"] = rustTargetDir.get().asFile.absolutePath
                env["TARGET"] = target.replace("21", "")
                
                exec {
                    commandLine("cargo", "build", "--release", "--target", target)
                    workingDir = file("${project.rootDir}/../rust")
                    environment(env)
                }
                
                // Copy .so to jniLibs
                val soSrc = file("${rustTargetDir.get().asFile}/$target/release/libpilinara_native.so")
                val soDest = file("src/main/jniLibs/$abi/libpilinara_native.so")
                soDest.parentFile.mkdirs()
                if (soSrc.exists()) {
                    soSrc.copyTo(soDest, overwrite = true)
                }
            }
        }
    }
    
    preBuild {
        dependsOn("cargoBuildRust")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(project(":danmaku-engine"))
    // Jetpack Compose UI
    implementation("androidx.compose.ui:ui:1.7.5")
    implementation("androidx.compose.material3:material3:1.3.1")
    implementation("androidx.compose.runtime:runtime:1.7.5")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.4")
    // Image loading
    implementation("io.coil-kt:coil-compose:2.6.0")
    // Media3
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-ui:1.5.1")
    // Networking
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.json:json:20240303")
    // JSON parsing
    implementation("com.google.code.gson:gson:2.12.1")
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
