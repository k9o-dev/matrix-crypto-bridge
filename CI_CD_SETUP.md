# CI/CD Pipeline Setup for Android AAR Building

This guide provides step-by-step instructions for setting up automated CI/CD pipelines to build the Android AAR (Android Archive) file using GitHub Actions.

## Table of Contents

1. [Overview](#overview)
2. [GitHub Actions Workflow](#github-actions-workflow)
3. [Setup Instructions](#setup-instructions)
4. [Build Artifacts](#build-artifacts)
5. [Troubleshooting](#troubleshooting)

---

## Overview

The CI/CD pipeline automates the following steps:

1. **Checkout code** from the repository
2. **Setup Rust** with Android targets
3. **Setup Android NDK** and SDK
4. **Build Rust libraries** for all Android targets (aarch64, armv7, x86_64)
5. **Generate Kotlin bindings** using UniFFI
6. **Build Android AAR** using Gradle
7. **Upload artifacts** for download

### Benefits

- ✅ Automated builds on every commit/tag
- ✅ Consistent build environment (no "works on my machine")
- ✅ Multi-platform support (macOS, Linux, Windows)
- ✅ Artifact storage for releases
- ✅ Build status notifications

---

## GitHub Actions Workflow

### File: `.github/workflows/build-android-aar.yml`

```yaml
name: Build Android AAR

on:
  push:
    branches:
      - main
      - master
      - develop
    tags:
      - 'v*'
  pull_request:
    branches:
      - main
      - master
  workflow_dispatch:  # Allow manual trigger

jobs:
  build-android-aar:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-linux-android,armv7-linux-androideabi,x86_64-linux-android
      
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      
      - name: Setup Android SDK
        uses: android-actions/setup-android@v3
      
      - name: Install Android NDK
        run: |
          $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --install "ndk;27.1.12297006"
          echo "ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/27.1.12297006" >> $GITHUB_ENV
      
      - name: Install uniffi-bindgen
        run: cargo install uniffi --features=cli
      
      - name: Build Rust for Android
        run: ./build-scripts/build-android.sh
      
      - name: Build Android AAR
        run: |
          cd matrix-crypto-android
          ./gradlew build
      
      - name: Upload AAR artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-aar
          path: matrix-crypto-android/build/outputs/aar/
          retention-days: 30
      
      - name: Upload to Release (on tag)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: matrix-crypto-android/build/outputs/aar/**/*.aar
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Setup Instructions

### Step 1: Create GitHub Actions Workflow File

1. In your repository, create the directory structure:
   ```bash
   mkdir -p .github/workflows
   ```

2. Create the workflow file:
   ```bash
   touch .github/workflows/build-android-aar.yml
   ```

3. Copy the workflow YAML above into the file

4. Commit and push:
   ```bash
   git add .github/workflows/build-android-aar.yml
   git commit -m "Add: GitHub Actions workflow for Android AAR building"
   git push origin master
   ```

### Step 2: Verify Workflow Setup

1. Go to your GitHub repository
2. Click the **Actions** tab
3. You should see the workflow listed as "Build Android AAR"
4. Click on it to view workflow details

### Step 3: Trigger a Build

The workflow will automatically trigger on:
- **Push to main/master/develop** — Every commit
- **Pull requests** — For code review
- **Tags** — When you create a release tag (e.g., `v1.0.0`)
- **Manual trigger** — Click "Run workflow" in the Actions tab

### Step 4: Download Build Artifacts

After the workflow completes:

1. Go to **Actions** tab
2. Click the latest workflow run
3. Scroll to **Artifacts** section
4. Download `android-aar` (contains the `.aar` file)

---

## Build Artifacts

### Output Structure

```
matrix-crypto-android/build/outputs/aar/
├── matrix-crypto-android-debug.aar
└── matrix-crypto-android-release.aar
```

### Using the AAR in Your Project

#### Option 1: Manual Import (Android Studio)

1. In Android Studio, go to **File → New → Import Module**
2. Select the AAR file
3. Add to your app's `build.gradle`:
   ```gradle
   dependencies {
       implementation project(':matrix-crypto-android')
   }
   ```

#### Option 2: Maven Local Repository

1. Publish AAR to local Maven repository:
   ```bash
   cd matrix-crypto-android
   ./gradlew publishToMavenLocal
   ```

2. In your app's `build.gradle`:
   ```gradle
   repositories {
       mavenLocal()
   }
   
   dependencies {
       implementation 'com.matrix.crypto:matrix-crypto-android:0.1.0'
   }
   ```

#### Option 3: GitHub Packages (Recommended)

1. Create a Personal Access Token (PAT) in GitHub:
   - Go to **Settings → Developer settings → Personal access tokens**
   - Click **Generate new token (classic)**
   - Select `write:packages` and `read:packages`
   - Copy the token

2. Update `matrix-crypto-android/build.gradle`:
   ```gradle
   publishing {
       repositories {
           maven {
               name = "GitHubPackages"
               url = uri("https://maven.pkg.github.com/techscorpion-dev/matrix-crypto-bridge")
               credentials {
                   username = System.getenv("GITHUB_ACTOR")
                   password = System.getenv("GITHUB_TOKEN")
               }
           }
       }
       publications {
           gpr(MavenPublication) {
               from(components.release)
           }
       }
   }
   ```

3. Add publish step to workflow:
   ```yaml
   - name: Publish to GitHub Packages
     if: startsWith(github.ref, 'refs/tags/')
     run: |
       cd matrix-crypto-android
       ./gradlew publish
     env:
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
   ```

4. In your app's `build.gradle`:
   ```gradle
   repositories {
       maven {
           url = uri("https://maven.pkg.github.com/techscorpion-dev/matrix-crypto-bridge")
           credentials {
               username = System.getenv("GITHUB_ACTOR")
               password = System.getenv("GITHUB_TOKEN")
           }
       }
   }
   
   dependencies {
       implementation 'com.matrix.crypto:matrix-crypto-android:0.1.0'
   }
   ```

---

## Advanced Configuration

### Build on Multiple Platforms

To build on macOS and Windows in addition to Linux:

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]

runs-on: ${{ matrix.os }}

steps:
  - name: Setup NDK (macOS)
    if: runner.os == 'macOS'
    run: |
      brew install android-ndk
      echo "ANDROID_NDK_HOME=$(brew --prefix android-ndk)" >> $GITHUB_ENV
  
  - name: Setup NDK (Windows)
    if: runner.os == 'Windows'
    run: |
      # Windows setup instructions
```

### Conditional Builds

Build only when specific files change:

```yaml
on:
  push:
    paths:
      - 'matrix-crypto-core/**'
      - 'matrix-crypto-android/**'
      - 'build-scripts/**'
      - '.github/workflows/build-android-aar.yml'
```

### Scheduled Builds

Build daily at 2 AM UTC:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'
```

### Build Status Badge

Add to your README.md:

```markdown
![Build Android AAR](https://github.com/techscorpion-dev/matrix-crypto-bridge/actions/workflows/build-android-aar.yml/badge.svg)
```

---

## Troubleshooting

### Issue: "NDK not found"

**Solution:** Ensure the NDK version in the workflow matches your local setup:

```yaml
- name: Install Android NDK
  run: |
    $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --install "ndk;27.1.12297006"
    echo "ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/27.1.12297006" >> $GITHUB_ENV
```

### Issue: "Gradle build failed"

**Solution:** Check the Gradle build output and ensure:
1. Java version is 17 or higher
2. Android SDK is properly installed
3. `build.gradle` has correct dependencies

### Issue: "Workflow not triggering"

**Solution:** 
1. Verify the workflow file is in `.github/workflows/`
2. Check branch name matches the `on.push.branches` configuration
3. Manually trigger with **Run workflow** button

### Issue: "Artifacts not uploading"

**Solution:** Ensure the AAR file path is correct:
```bash
# Verify AAR exists
ls -la matrix-crypto-android/build/outputs/aar/
```

---

## Best Practices

1. **Use tags for releases:**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. **Automate version bumping:**
   - Use `semantic-release` or `conventional-commits`
   - Automatically create releases on version change

3. **Test before building:**
   - Add unit tests to the pipeline
   - Run lint checks
   - Validate Kotlin code

4. **Monitor build status:**
   - Set up Slack notifications
   - Configure email alerts
   - Use GitHub status checks

5. **Cache dependencies:**
   ```yaml
   - name: Cache Rust
     uses: Swatinem/rust-cache@v2
   
   - name: Cache Gradle
     uses: gradle/gradle-build-action@v2
   ```

---

## Next Steps

1. Create the workflow file in your repository
2. Push to GitHub
3. Verify the workflow appears in the Actions tab
4. Trigger a manual build to test
5. Download and verify the AAR artifact
6. Integrate into your React Native app

For questions or issues, refer to:
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Android Gradle Plugin Documentation](https://developer.android.com/studio/build)
- [Rust Android Documentation](https://rust-lang.github.io/rustup/cross-compilation.html)
