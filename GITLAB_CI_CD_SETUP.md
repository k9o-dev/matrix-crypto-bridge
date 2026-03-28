# GitLab CI/CD Pipeline Setup for Android AAR and iOS XCFramework

This guide provides step-by-step instructions for setting up automated CI/CD pipelines using GitLab CI to build the Android AAR and iOS XCFramework.

## Table of Contents

1. [Overview](#overview)
2. [GitLab CI/CD Configuration](#gitlab-cicd-configuration)
3. [Setup Instructions](#setup-instructions)
4. [Build Artifacts](#build-artifacts)
5. [Advanced Configuration](#advanced-configuration)
6. [Troubleshooting](#troubleshooting)

---

## Overview

The GitLab CI/CD pipeline automates the following steps:

1. **Checkout code** from the repository
2. **Setup Rust** with Android/iOS targets
3. **Setup Android NDK** and SDK (for Android builds)
4. **Setup Xcode** (for iOS builds)
5. **Build Rust libraries** for all targets
6. **Generate language bindings** (Kotlin, Swift)
7. **Build Android AAR** using Gradle
8. **Build iOS XCFramework**
9. **Store artifacts** for download and release

### Benefits

- ✅ Automated builds on every commit/tag/MR
- ✅ Parallel builds for Android and iOS
- ✅ Consistent build environment
- ✅ Built-in artifact storage
- ✅ Pipeline status notifications
- ✅ Scheduled builds support
- ✅ Manual trigger capability

---

## GitLab CI/CD Configuration

### File: `.gitlab-ci.yml`

```yaml
# Matrix Crypto Bridge - GitLab CI/CD Pipeline
# Builds Android AAR and iOS XCFramework

stages:
  - build
  - package
  - release

variables:
  RUST_BACKTRACE: "1"
  CARGO_TERM_COLOR: "always"

# Android Build Job
build:android:
  stage: build
  image: ubuntu:22.04
  
  variables:
    ANDROID_NDK_VERSION: "27.1.12297006"
    JAVA_HOME: "/usr/lib/jvm/java-17-temurin"
  
  before_script:
    # Update package manager
    - apt-get update -qq
    - apt-get install -y -qq curl wget git build-essential pkg-config
    
    # Install Rust
    - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    - source $HOME/.cargo/env
    - rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
    
    # Install Java
    - apt-get install -y -qq openjdk-17-jdk-headless
    
    # Install Android SDK/NDK
    - apt-get install -y -qq android-sdk
    - export ANDROID_SDK_ROOT=/usr/lib/android-sdk
    - export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION
    
    # Install uniffi-bindgen
    - cargo install uniffi --features=cli
  
  script:
    # Build Rust for Android
    - echo "Building Rust for Android..."
    - chmod +x ./build-scripts/build-android.sh
    - ./build-scripts/build-android.sh
    
    # Build Android AAR
    - echo "Building Android AAR..."
    - cd matrix-crypto-android
    - chmod +x ./gradlew
    - ./gradlew build
    - cd ..
  
  artifacts:
    paths:
      - matrix-crypto-android/build/outputs/aar/
      - matrix-crypto-android/generated/
    expire_in: 30 days
    when: always
  
  cache:
    paths:
      - .cargo/
      - target/
      - matrix-crypto-android/.gradle/
  
  only:
    - branches
    - tags
    - merge_requests
  
  tags:
    - linux
    - docker

# iOS Build Job
build:ios:
  stage: build
  image: macos-12
  
  variables:
    RUST_BACKTRACE: "1"
  
  before_script:
    # Install Rust
    - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    - source $HOME/.cargo/env
    - rustup target add aarch64-apple-ios x86_64-apple-ios
    
    # Install uniffi-bindgen
    - cargo install uniffi --features=cli
  
  script:
    # Build Rust for iOS
    - echo "Building Rust for iOS..."
    - chmod +x ./build-scripts/build-ios.sh
    - ./build-scripts/build-ios.sh
  
  artifacts:
    paths:
      - matrix-crypto-ios/build/MatrixCryptoBridge.xcframework/
      - matrix-crypto-ios/generated/
    expire_in: 30 days
    when: always
  
  cache:
    paths:
      - .cargo/
      - target/
  
  only:
    - branches
    - tags
    - merge_requests
  
  tags:
    - macos
    - xcode

# Package Job - Combine artifacts
package:artifacts:
  stage: package
  image: ubuntu:22.04
  
  dependencies:
    - build:android
    - build:ios
  
  script:
    - echo "Packaging build artifacts..."
    - mkdir -p artifacts/android artifacts/ios
    - cp -r matrix-crypto-android/build/outputs/aar/* artifacts/android/ || true
    - cp -r matrix-crypto-ios/build/MatrixCryptoBridge.xcframework artifacts/ios/ || true
    - ls -lah artifacts/
  
  artifacts:
    paths:
      - artifacts/
    expire_in: 90 days
  
  only:
    - tags
    - main
    - master

# Release Job - Create GitLab release
release:artifacts:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  
  dependencies:
    - build:android
    - build:ios
  
  script:
    - echo "Creating release..."
  
  release:
    tag_name: $CI_COMMIT_TAG
    name: "Release $CI_COMMIT_TAG"
    description: "Build artifacts for $CI_COMMIT_TAG"
    assets:
      links:
        - name: "Android AAR"
          url: "${CI_PROJECT_URL}/-/jobs/${CI_JOB_ID}/artifacts/raw/matrix-crypto-android/build/outputs/aar/matrix-crypto-android-release.aar"
          link_type: other
        - name: "iOS XCFramework"
          url: "${CI_PROJECT_URL}/-/jobs/${CI_JOB_ID}/artifacts/raw/matrix-crypto-ios/build/MatrixCryptoBridge.xcframework"
          link_type: other
  
  only:
    - tags
  
  tags:
    - linux
    - docker

# Scheduled Build Job
build:scheduled:
  stage: build
  image: ubuntu:22.04
  script:
    - echo "Running scheduled build..."
    - chmod +x ./build-scripts/build-android.sh
    - ./build-scripts/build-android.sh
  only:
    - schedules
  tags:
    - linux
    - docker
```

---

## Setup Instructions

### Step 1: Prepare Your GitLab Repository

If you haven't already, push your code to GitLab:

```bash
# Add GitLab remote
git remote add gitlab https://gitlab.com/your-username/matrix-crypto-bridge.git

# Push to GitLab
git push gitlab master
```

### Step 2: Add `.gitlab-ci.yml` to Your Repository

```bash
# Copy the configuration file
cp .gitlab-ci.yml .gitlab-ci.yml

# Or create it manually
cat > .gitlab-ci.yml << 'EOF'
# [Paste the YAML content from above]
EOF

# Commit and push
git add .gitlab-ci.yml
git commit -m "Add: GitLab CI/CD pipeline configuration"
git push gitlab master
```

### Step 3: Configure GitLab Runners

GitLab CI/CD requires runners to execute jobs. You have two options:

#### Option A: Use GitLab.com Shared Runners (Easiest)

1. Go to your GitLab project
2. Click **Settings → CI/CD → Runners**
3. Verify that **Shared runners** are enabled
4. No additional setup needed!

#### Option B: Use Self-Hosted Runners (More Control)

For better performance and customization:

```bash
# Install GitLab Runner
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Register Linux runner for Android builds
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_REGISTRATION_TOKEN \
  --executor docker \
  --docker-image ubuntu:22.04 \
  --description "Android Build Runner" \
  --tag-list linux,docker

# Register macOS runner for iOS builds
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_REGISTRATION_TOKEN \
  --executor shell \
  --description "iOS Build Runner" \
  --tag-list macos,xcode
```

### Step 4: Verify Pipeline Setup

1. Go to your GitLab project
2. Click **CI/CD → Pipelines**
3. You should see pipelines listed
4. Click on a pipeline to view job details

### Step 5: Trigger a Build

Builds are triggered automatically on:
- **Push to any branch** — Runs all jobs
- **Merge requests** — Runs all jobs
- **Tags** — Runs all jobs + creates release
- **Scheduled** — Runs on schedule (if configured)

To manually trigger:

1. Go to **CI/CD → Pipelines**
2. Click **Run Pipeline**
3. Select branch and click **Create pipeline**

---

## Build Artifacts

### Artifact Locations

| Artifact | Location | Retention |
|----------|----------|-----------|
| Android AAR (Release) | `matrix-crypto-android/build/outputs/aar/matrix-crypto-android-release.aar` | 30 days |
| Android AAR (Debug) | `matrix-crypto-android/build/outputs/aar/matrix-crypto-android-debug.aar` | 30 days |
| Kotlin Bindings | `matrix-crypto-android/generated/` | 30 days |
| iOS XCFramework | `matrix-crypto-ios/build/MatrixCryptoBridge.xcframework/` | 30 days |
| Swift Bindings | `matrix-crypto-ios/generated/` | 30 days |

### Downloading Artifacts

#### From Pipeline View

1. Go to **CI/CD → Pipelines**
2. Click on a pipeline
3. Click the job (e.g., `build:android`)
4. Click **Download artifacts** button

#### From Job View

1. Go to **CI/CD → Jobs**
2. Click on a job
3. Right panel shows **Artifacts** section
4. Click artifact name to download

#### Using GitLab API

```bash
# Download Android AAR
curl --output app.aar \
  "https://gitlab.com/api/v4/projects/PROJECT_ID/jobs/JOB_ID/artifacts/matrix-crypto-android/build/outputs/aar/matrix-crypto-android-release.aar" \
  --header "PRIVATE-TOKEN: YOUR_ACCESS_TOKEN"
```

---

## Advanced Configuration

### Scheduled Builds

To run builds on a schedule (e.g., daily):

1. Go to **CI/CD → Schedules**
2. Click **New schedule**
3. Set frequency (e.g., "Every day at 2:00 AM")
4. Select branch (e.g., `master`)
5. Click **Save pipeline schedule**

The `build:scheduled` job will run automatically.

### Conditional Builds

Build only when specific files change:

```yaml
build:android:
  only:
    changes:
      - matrix-crypto-core/**/*
      - matrix-crypto-android/**/*
      - build-scripts/**/*
      - .gitlab-ci.yml
```

### Manual Job Trigger

Allow manual triggering of specific jobs:

```yaml
build:android:
  when: manual
```

Then click **Play** button in the pipeline view.

### Environment-Specific Variables

Set different variables for different environments:

```yaml
build:android:
  variables:
    ANDROID_NDK_VERSION: "27.1.12297006"
  environment:
    name: production
```

### Notifications

#### Slack Integration

1. Go to **Settings → Integrations → Slack**
2. Enter your Slack webhook URL
3. Select events to notify on
4. Click **Test** and **Save**

#### Email Notifications

1. Go to **Settings → Notifications**
2. Select notification level
3. Choose events to notify on

### Build Status Badge

Add to your README.md:

```markdown
[![pipeline status](https://gitlab.com/your-username/matrix-crypto-bridge/badges/master/pipeline.svg)](https://gitlab.com/your-username/matrix-crypto-bridge/-/commits/master)
```

---

## Troubleshooting

### Issue: "No runners available"

**Solution:** 
- Ensure runners are registered and tagged correctly
- Check runner tags match job tags
- Go to **Settings → CI/CD → Runners** to verify

```bash
# List registered runners
sudo gitlab-runner list

# Verify runner is online
sudo gitlab-runner verify
```

### Issue: "Job failed: exit code 1"

**Solution:**
1. Click on the failed job
2. Scroll to see full build output
3. Look for error messages
4. Common issues:
   - Missing dependencies (install in `before_script`)
   - Wrong paths (check working directory)
   - NDK not found (verify NDK_HOME)

### Issue: "Artifacts not found"

**Solution:**
- Verify artifact paths in the job
- Check that job completed successfully
- Ensure `artifacts:` section is configured
- Check artifact retention hasn't expired

```bash
# Verify artifacts exist
ls -la matrix-crypto-android/build/outputs/aar/
```

### Issue: "Runner timeout"

**Solution:**
- Increase timeout in job configuration:
  ```yaml
  build:android:
    timeout: 2 hours
  ```
- Optimize build process
- Use caching to speed up builds

### Issue: "Out of disk space"

**Solution:**
- Reduce artifact retention:
  ```yaml
  artifacts:
    expire_in: 7 days  # Reduce from 30 days
  ```
- Clear old artifacts manually
- Use self-hosted runner with more storage

---

## Performance Optimization

### Caching

Cache dependencies to speed up builds:

```yaml
cache:
  paths:
    - .cargo/
    - target/
    - matrix-crypto-android/.gradle/
  key:
    files:
      - Cargo.lock
      - matrix-crypto-android/build.gradle
```

### Parallel Builds

Android and iOS builds run in parallel automatically:

```yaml
stages:
  - build        # Both jobs run simultaneously
  - package      # Waits for all build jobs
  - release      # Final stage
```

### Incremental Builds

Use Rust incremental compilation:

```yaml
variables:
  CARGO_INCREMENTAL: "1"
```

---

## Comparison: GitHub Actions vs GitLab CI/CD

| Feature | GitHub Actions | GitLab CI/CD |
|---------|----------------|-------------|
| **Setup** | Workflows in `.github/workflows/` | Single `.gitlab-ci.yml` file |
| **Runners** | Shared runners included | Shared runners included |
| **Parallelization** | Jobs run in parallel | Jobs run in parallel |
| **Caching** | Per-workflow | Per-pipeline |
| **Artifacts** | 30-90 days retention | Configurable retention |
| **Releases** | Automatic release creation | Manual release creation |
| **Notifications** | Built-in integrations | Slack, email, webhooks |
| **Cost** | Free for public repos | Free for public repos |
| **Complexity** | Multiple YAML files | Single YAML file |

---

## Next Steps

1. **Add `.gitlab-ci.yml`** to your repository
2. **Push to GitLab** and verify pipeline appears
3. **Configure runners** (use shared runners or self-hosted)
4. **Trigger a build** manually to test
5. **Download artifacts** to verify they work
6. **Set up notifications** for build status
7. **Integrate into your React Native app**

For more information:
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
