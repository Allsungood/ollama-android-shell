plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
}

android {
  namespace = "com.ollamadeck.shell"
  compileSdk = 36

  defaultConfig {
    applicationId = "com.ollamadeck.shell"
    minSdk = 26
    // targetSdk 34: keep native exec of the embedded termux/ollama ELFs working on
    // Android 15/16 (targetSdk 35+ forbids exec of app-data ELF without linker64 wrappers).
    targetSdk = 34
    versionCode = 1
    versionName = "0.1.0"
    buildConfigField("String", "TERMUX_VERSION", "\"0.118.3\"")
    buildConfigField("int", "OLLAMA_PORT", "11434")
  }

  buildFeatures {
    buildConfig = true
  }

  androidResources {
    // termux-runtime.tar.xz is already xz-compressed; double-compressing breaks openFd.
    noCompress += "xz"
  }

  signingConfigs {
    // Fixed debugging from the repo keystore so CI/local builds share one signature
    // (users can overwrite-install without INSTALL_FAILED_UPDATE_INCOMPATIBLE).
    create("repoDebug") {
      storeFile = rootProject.file("keystore/debug.keystore")
      storePassword = "android"
      keyAlias = "androiddebugkey"
      keyPassword = "android"
    }
  }

  buildTypes {
    release {
      isMinifyEnabled = false
    }
    debug {
      signingConfig = signingConfigs.getByName("repoDebug")
    }
  }

  lint {
    checkReleaseBuilds = false
    abortOnError = false
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = "17"
  }
}

// The Termux runtime snapshot is large and not committed; the build fails with fetch
// guidance when it is missing so users don't accidentally bake in an empty runtime.
tasks.whenTaskAdded {
  if (name == "mergeDebugAssets" || name == "mergeReleaseAssets") {
    doFirst {
      val snap = file("src/main/assets/termux-runtime.tar.xz")
      if (!snap.exists()) {
        throw GradleException(
          "缺少运行时快照 assets/termux-runtime.tar.xz —— " +
            "从 Releases 下载 termux-runtime-<abi>.tar.xz 放到 app/src/main/assets/termux-runtime.tar.xz，或用 scripts/build-apk.mjs 一键打包（见 docs/PLAN.md）。",
        )
      }
    }
  }
}

dependencies {
  implementation("androidx.activity:activity-ktx:1.10.1")
  implementation("androidx.core:core-ktx:1.15.0")
  implementation("org.apache.commons:commons-compress:1.28.0")
  implementation("org.tukaani:xz:1.10")
}