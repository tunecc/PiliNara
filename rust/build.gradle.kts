// Rust build integration for PiliNara
// This script is sourced by android/app/build.gradle.kts

import org.gradle.api.tasks.Exec
import java.io.File

// Cargo/Rust configuration
val rustProjectDir = file("../rust")
val cargoTargetDir = file("$buildDir/rust-target")

// Android ABI targets
val androidAbis = listOf(
    "arm64-v8a" to "aarch64-linux-android",
    "armeabi-v7a" to "armv7-linux-androideabi",
    "x86_64" to "x86_64-linux-android",
    "x86" to "i686-linux-android"
)

// NDK toolchain info (inherited from Flutter's NDK)
val ndkVersion = project.ext.has("ndkVersion") ? project.ext.get("ndkVersion") : "27.0.12077973"

// Task: build Rust library for all Android ABIs
tasks.register<Exec>("cargoBuildAndroid") {
    group = "rust"
    description = "Build Rust native library for all Android ABIs"
    
    val ndkHome = System.getenv("ANDROID_NDK_HOME") ?: findNdkHome()
    val toolchainRoot = File(ndkHome, "toolchains/llvm/prebuilt/linux-x86_64")
    
    for ((abi, target) in androidAbis) {
        val outputDir = file("$buildDir/intermediates/rust/debug/$abi")
        val libName = if (abi == "arm64-v8a") "aarch64" else if (abi == "armeabi-v7a") "arm" else abi
        
        doLast {
            // Set environment for cross-compilation
            environment("TARGET", target)
            environment("CROSS_COMPILE", "${toolchainRoot}/bin/${target25-}")
            environment("NDK_HOME", ndkHome)
            
            // Build with cargo
            val cargoCmd = arrayOf(
                "cargo", "build",
                "--target", target,
                "--target-dir", cargoTargetDir.absolutePath,
                "--quiet"
            )
            exec {
                commandLine(*cargoCmd)
                workingDir = rustProjectDir
            }
        }
    }
}

fun findNdkHome(): String {
    val localProperties = File("local.properties")
    if (localProperties.exists()) {
        val props = java.util.Properties()
        localProperties.inputStream().use { props.load(it) }
        val sdkHome = props.getProperty("sdk.dir")
        if (sdkHome != null) {
            val ndkPaths = listOf(
                "$sdkHome/ndk/${project.ext.get("ndkVersion")}",
                "$sdkHome/ndk/bundle",
                "$sdkHome/ndk/latest"
            )
            for (path in ndkPaths) {
                if (File(path).exists()) return path
            }
        }
    }
    return System.getenv("ANDROID_NDK_HOME") ?: ""
}
