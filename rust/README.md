# PiliNara Native (Rust)

Native Rust library for PiliNara Android app. Provides high-performance implementations of:

- **Animated WebP encoding** — replaces Android's `Bitmap.compress()` with a pure Rust implementation
- **Audio normalization** — dynaudnorm-style loudness normalization for audio playback

## Building

### Prerequisites

- Rust toolchain (`rustup`)
- Android NDK r27+
- Target triples installed:
  ```bash
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
  ```

### Build for Android (manual)

```bash
# Set up environment
export ANDROID_NDK_HOME=/path/to/android-ndk-r27b
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"

# Build for each ABI
for target in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android; do
  cargo build --release --target $target
done
```

### Build via CI

Push to the `feat/kotlin-rust-build` branch or open a PR targeting `main` to trigger the CI build.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Flutter (Dart)                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │ ExoPlayerController (Dart)                  │   │
│  │  - MethodChannel: com.example.piliplus/...  │   │
│  └──────────────────┬──────────────────────────┘   │
│                     │ Platform Channel              │
├─────────────────────┼───────────────────────────────┤
│  Android (Kotlin)                                  │
│  ┌─────────────────────────────────────────────┐   │
│  │ ExoPlayerPlugin.kt                          │   │
│  │  - WebpNativeLib.encode()                   │   │
│  │  - AudioNativeLib.normalizeAudio()          │   │
│  └──────────────────┬──────────────────────────┘   │
│                     │ JNI                          │
├─────────────────────┼───────────────────────────────┤
│  Native (Rust)                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │ pilinara_native crate                       │   │
│  │  - webp::AnimatedWebpEncoder                │   │
│  │  - audio::AudioNormalizer                   │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## JNI Interface

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `WebpNativeLib_create` | width, height | jlong (pointer) | Create encoder, -1 on error |
| `WebpNativeLib_addFrame` | ptr, data, durationMs, x, y | jint (0=ok) | Add VP8 frame |
| `WebpNativeLib_finalize` | ptr | ByteArray | Finalize and return WebP bytes |
| `AudioNativeLib_normalize` | input, channels | ByteArray | Normalize PCM samples |

## Testing

```bash
# Run unit tests (host target)
cd rust
cargo test

# Cross-compile check (Android targets)
cargo check --target aarch64-linux-android
cargo check --target armv7-linux-androideabi
```
