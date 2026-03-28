# GitLab CI/CD Pipeline Setup for NPM Publishing

This guide provides step-by-step instructions for setting up automated CI/CD pipelines using GitLab CI to build native libraries and publish the `@k9o/react-native-matrix-crypto` package to NPM.

## Table of Contents

1. [Overview](#overview)
2. [GitLab CI/CD Configuration](#gitlab-cicd-configuration)
3. [Setup Instructions](#setup-instructions)
4. [Build Process](#build-process)
5. [Publishing to NPM](#publishing-to-npm)
6. [Advanced Configuration](#advanced-configuration)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The GitLab CI/CD pipeline automates the complete build and publish process:

1. **Build iOS Libraries** (macOS runner)
   - Compile for aarch64-apple-ios (device)
   - Compile for x86_64-apple-ios (simulator)

2. **Build Android Libraries** (Ubuntu runner)
   - Compile for aarch64-linux-android (ARM64)
   - Compile for armv7-linux-androideabi (ARMv7)
   - Compile for x86_64-linux-android (x86_64)

3. **Package for NPM** (Ubuntu runner)
   - Download all build artifacts
   - Organize iOS libraries in `ios/prebuilt/`
   - Organize Android libraries in `android/src/main/jniLibs/`
   - Build TypeScript
   - Verify package contents

4. **Publish to NPM** (Ubuntu runner)
   - Publish to NPM registry
   - Create GitLab Release with build information

### Benefits

- ✅ Fully automated builds on version tags
- ✅ Pre-built native libraries included in NPM package
- ✅ Auto-linking via CocoaPods (iOS) and Gradle (Android)
- ✅ Parallel builds for iOS and Android
- ✅ Consistent build environment
- ✅ Multi-platform support (iOS device, iOS simulator, Android ARM64/ARMv7/x86_64)
- ✅ Built-in artifact storage
- ✅ Pipeline status notifications

---

## GitLab CI/CD Configuration

### File: `.gitlab-ci.yml`

```yaml
# Matrix Crypto Bridge - GitLab CI/CD Pipeline
# Builds native libraries and publishes to NPM

stages:
  - build
  - package
  - publish
  - notify

variables:
  RUST_BACKTRACE: "1"
  CARGO_TERM_COLOR: "always"

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
  
  script:
    - echo "Building iOS libraries..."
    - chmod +x ./build-scripts/build-ios.sh
    - ./build-scripts/build-ios.sh
  
  artifacts:
    paths:
      - matrix-crypto-core/target/aarch64-apple-ios/release/libmatrix_crypto_core.a
      - matrix-crypto-core/target/x86_64-apple-ios/release/libmatrix_crypto_core.a
    expire_in: 1 day
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

# Android Build Job
build:android:
  stage: build
  image: ubuntu:22.04
  
  variables:
    ANDROID_NDK_VERSION: "r25c"
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
  
  script:
    - echo "Building Android libraries..."
    - chmod +x ./build-scripts/build-android.sh
    - ./build-scripts/build-android.sh
  
  artifacts:
    paths:
      - matrix-crypto-core/target/aarch64-linux-android/release/libmatrix_crypto_core.so
      - matrix-crypto-core/target/armv7-linux-androideabi/release/libmatrix_crypto_core.so
      - matrix-crypto-core/target/x86_64-linux-android/release/libmatrix_crypto_core.so
    expire_in: 1 day
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
    - linux
    - docker

# Package Job - Combine artifacts
package:npm:
  stage: package
  image: ubuntu:22.04
  
  dependencies:
    - build:ios
    - build:android
  
  before_script:
    - apt-get update -qq
    - apt-get install -y -qq curl
    - curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    - apt-get install -y -qq nodejs
  
  script:
    - echo "Packaging for NPM..."
    - mkdir -p react-native-matrix-crypto/ios/prebuilt
    - mkdir -p react-native-matrix-crypto/android/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}
    
    # Copy iOS libraries
    - cp matrix-crypto-core/target/aarch64-apple-ios/release/libmatrix_crypto_core.a react-native-matrix-crypto/ios/prebuilt/libmatrix_crypto_core_arm64.a
    - cp matrix-crypto-core/target/x86_64-apple-ios/release/libmatrix_crypto_core.a react-native-matrix-crypto/ios/prebuilt/libmatrix_crypto_core_sim.a
    
    # Copy Android libraries
    - cp matrix-crypto-core/target/aarch64-linux-android/release/libmatrix_crypto_core.so react-native-matrix-crypto/android/src/main/jniLibs/arm64-v8a/
    - cp matrix-crypto-core/target/armv7-linux-androideabi/release/libmatrix_crypto_core.so react-native-matrix-crypto/android/src/main/jniLibs/armeabi-v7a/
    - cp matrix-crypto-core/target/x86_64-linux-android/release/libmatrix_crypto_core.so react-native-matrix-crypto/android/src/main/jniLibs/x86_64/
    
    # Build TypeScript
    - cd react-native-matrix-crypto
    - npm install
    - npm run build
    - cd ..
    
    # Verify package contents
    - echo "=== iOS Libraries ===" && ls -lh react-native-matrix-crypto/ios/prebuilt/
    - echo "=== Android Libraries ===" && find react-native-matrix-crypto/android/src/main/jniLibs -name "*.so" -exec ls -lh {} \;
  
  artifacts:
    paths:
      - react-native-matrix-crypto/
    expire_in: 7 days
    when: always
  
  only:
    - tags
    - main
    - master
    - develop
  
  tags:
    - linux
    - docker

# Publish Job - Publish to NPM
publish:npm:
  stage: publish
  image: ubuntu:22.04
  
  dependencies:
    - package:npm
  
  before_script:
    - apt-get update -qq
    - apt-get install -y -qq curl
    - curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    - apt-get install -y -qq nodejs
    - cd react-native-matrix-crypto
    - npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN
  
  script:
    - echo "Publishing to NPM..."
    - npm publish --access public
  
  only:
    - tags
  
  tags:
    - linux
    - docker

# Release Job - Create GitLab release
release:artifacts:
  stage: publish
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  
  dependencies:
    - build:ios
    - build:android
  
  script:
    - echo "Creating release..."
  
  release:
    tag_name: $CI_COMMIT_TAG
    name: "Release $CI_COMMIT_TAG"
    description: "Build artifacts for $CI_COMMIT_TAG"
    assets:
      links:
        - name: "NPM Package"
          url: "https://www.npmjs.com/package/@k9o/react-native-matrix-crypto"
          link_type: other
  
  only:
    - tags
  
  tags:
    - linux
    - docker

# Notify Job - Pipeline completion
notify:completion:
  stage: notify
  image: ubuntu:22.04
  
  script:
    - echo "Pipeline completed!"
    - |
      if [ "$CI_JOB_STATUS" == "success" ]; then
        echo "✅ Build and publish successful!"
      else
        echo "❌ Build or publish failed!"
      fi
  
  when: always
  
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
# Create the file
cat > .gitlab-ci.yml << 'EOF'
# [Paste the YAML content from above]
EOF

# Commit and push
git add .gitlab-ci.yml
git commit -m "Add: GitLab CI/CD pipeline configuration for NPM publishing"
git push gitlab master
```

### Step 3: Configure GitLab CI/CD Variables

1. Go to your GitLab project
2. Click **Settings → CI/CD → Variables**
3. Click **Add variable**
4. Add the following variables:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `NPM_TOKEN` | Your NPM authentication token | Yes | Yes |

**To create NPM token:**
```bash
npm login
npm token create --read-only
```

### Step 4: Configure GitLab Runners

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

### Step 5: Verify Pipeline Setup

1. Go to your GitLab project
2. Click **CI/CD → Pipelines**
3. You should see pipelines listed
4. Click on a pipeline to view job details

### Step 6: Test Local Build

Before publishing, test the build scripts locally:

```bash
# Build all platforms
bash build-scripts/build-and-package.sh all

# Verify package contents
ls -la react-native-matrix-crypto/ios/prebuilt/
ls -la react-native-matrix-crypto/android/src/main/jniLibs/
```

---

## Build Process

### Triggering Builds

Builds are triggered automatically on:

- **Push to any branch** — Runs all build jobs
- **Merge requests** — Runs all build jobs
- **Tags** — Runs all jobs + publishes to NPM + creates release
- **Scheduled** — Runs on schedule (if configured)

### Manual Trigger

To manually trigger a build:

1. Go to **CI/CD → Pipelines**
2. Click **Run Pipeline**
3. Select branch and click **Create pipeline**

---

## Publishing to NPM

### Automatic Publishing

When you push a git tag, the pipeline automatically:

1. Builds iOS and Android libraries
2. Packages for NPM
3. Publishes to NPM
4. Creates GitLab Release

```bash
# 1. Update version
npm version patch    # or minor/major

# 2. Create git tag
git tag -a v1.1.0 -m "Release v1.1.0"

# 3. Push to GitLab
git push gitlab main
git push gitlab v1.1.0

# GitLab CI/CD automatically publishes
```

### Manual Publishing

If you need to publish manually:

```bash
cd react-native-matrix-crypto

# Ensure everything is built
npm run build

# Verify package contents
npm pack --dry-run

# Publish to NPM
npm publish --access public
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

### Conditional Builds

Build only when specific files change:

```yaml
build:android:
  only:
    changes:
      - matrix-crypto-core/**/*
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

### Issue: "NPM publish failed"

**Solution:**
1. Verify `NPM_TOKEN` is set correctly
2. Check token has `write:packages` permission
3. Verify package name is correct
4. Check version number is unique

### Issue: "Runner timeout"

**Solution:**
- Increase timeout in job configuration:
  ```yaml
  build:android:
    timeout: 2 hours
  ```
- Optimize build process
- Use caching to speed up builds

---

## Best Practices

1. **Use semantic versioning:**
   ```bash
   npm version patch    # Bug fixes (1.0.0 → 1.0.1)
   npm version minor    # New features (1.0.0 → 1.1.0)
   npm version major    # Breaking changes (1.0.0 → 2.0.0)
   ```

2. **Test locally before publishing:**
   ```bash
   bash build-scripts/build-and-package.sh all
   npm link
   # Test in app
   npm unlink
   ```

3. **Update changelog:**
   - Document all changes
   - Include breaking changes
   - Link to related issues

4. **Monitor build status:**
   - Check CI/CD → Pipelines regularly
   - Set up Slack notifications
   - Review build logs for warnings

5. **Cache dependencies:**
   ```yaml
   cache:
     paths:
       - .cargo/
       - target/
   ```

---

## Next Steps

1. Add `.gitlab-ci.yml` to your repository
2. Configure `NPM_TOKEN` in CI/CD variables
3. Setup runners (shared or self-hosted)
4. Test local build with `build-scripts/build-and-package.sh all`
5. Create a test release with `npm version patch`
6. Push git tag to trigger automated build
7. Verify package on NPM registry

---

## Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [NPM Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [Semantic Versioning](https://semver.org/)
- [React Native Native Modules](https://reactnative.dev/docs/native-modules-intro)
