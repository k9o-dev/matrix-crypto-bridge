# Matrix Crypto Bridge - CI/CD Guide

## Overview

The Matrix Crypto Bridge uses GitHub Actions to automate building, testing, and publishing native libraries for iOS and Android platforms.

## Workflow: Build and Publish to NPM

**File:** `.github/workflows/build-and-publish-workspace.yml`

### Triggers

The workflow runs on:

1. **Push to branches:**
   - `main`, `develop`, `master`
   - Builds all platforms but does NOT publish

2. **Push to tags:**
   - Tags matching `v*` (e.g., `v0.1.0`, `v1.0.0`)
   - Builds all platforms AND publishes to GitHub Releases + NPM

3. **Pull requests:**
   - To `main`, `develop`, `master`
   - Builds all platforms for validation

4. **Manual trigger:**
   - Via GitHub Actions UI
   - Optional inputs for publishing

## Jobs

### 1. build-ios (macOS)

**Runner:** `macos-latest`

**Steps:**
1. Checkout code
2. Install Rust + iOS targets (aarch64, x86_64)
3. Cache Rust dependencies
4. Build iOS libraries (both targets)
5. Generate Swift bindings
6. Upload artifacts (30-day retention)

**Output:**
- `libmatrix_crypto_ios_aarch64-apple-ios.a` (27 MB)
- `libmatrix_crypto_ios_x86_64-apple-ios.a` (27 MB)
- `matrix_crypto.swift` (Swift bindings)

**Time:** ~5-8 minutes

### 2. build-android (Ubuntu)

**Runner:** `ubuntu-latest`

**Steps:**
1. Checkout code
2. Install Rust + Android targets (aarch64, armv7, x86_64)
3. Setup Android NDK r26
4. Verify NDK installation
5. Install cargo-ndk
6. Cache Rust dependencies
7. Build Android libraries (all ABIs)
8. Verify artifacts
9. Generate Kotlin bindings
10. Upload artifacts (30-day retention)

**Output:**
- `libmatrix_crypto_android.so` (aarch64)
- `libmatrix_crypto_android.so` (armv7)
- `libmatrix_crypto_android.so` (x86_64)
- `matrix_crypto.kt` (Kotlin bindings)

**Time:** ~8-12 minutes

**Environment:**
- `ANDROID_NDK_HOME` automatically set by setup-ndk action
- NDK r26 includes all required toolchains

### 3. create-distribution

**Runner:** `ubuntu-latest`

**Depends on:** build-ios, build-android (runs even if one fails)

**Steps:**
1. Create dist directory structure
2. Download iOS artifacts
3. Download Swift bindings
4. Download Android artifacts
5. Download Kotlin bindings
6. List distribution contents
7. Create tar.gz archive
8. Generate SHA256 checksum
9. Upload distribution archive (90-day retention)

**Output:**
- `matrix-crypto-bridge-dist.tar.gz` (complete distribution)
- `matrix-crypto-bridge-dist.tar.gz.sha256` (integrity checksum)

**Time:** ~2-3 minutes

### 4. build-status (Always runs)

**Runner:** `ubuntu-latest`

**Purpose:** Generate build report and status notifications

**Output:**
- Build status for each platform
- Summary of what was built
- Notifications on success/partial success

**Time:** <1 minute

### 5. publish-release (On tags only)

**Runner:** `ubuntu-latest`

**Depends on:** create-distribution

**Triggers:** When git tag matches `v*`

**Steps:**
1. Checkout code
2. Download distribution archive
3. Verify archive integrity (SHA256)
4. Create GitHub Release with:
   - Distribution archive
   - Checksum file
   - Detailed release notes
   - Installation instructions

**Time:** ~1-2 minutes

### 6. publish-npm (On tags only)

**Runner:** `ubuntu-latest`

**Depends on:** create-distribution, publish-release

**Triggers:** When git tag matches `v*`

**Steps:**
1. Checkout code
2. Setup Node.js 20
3. Download distribution archive
4. Extract distribution
5. Install npm dependencies
6. Verify package contents
7. Publish to NPM registry
8. Verify publication

**Requires:** `NPM_TOKEN` secret in GitHub

**Time:** ~3-5 minutes

## Secrets Required

### GitHub Secrets

Add these to your repository settings (Settings → Secrets and variables → Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `NPM_TOKEN` | NPM authentication token | `npm_xxxxxxxxxxxx` |

**How to get NPM_TOKEN:**
1. Go to https://www.npmjs.com/settings/tokens
2. Create new token (Automation type)
3. Copy the token
4. Add to GitHub Secrets as `NPM_TOKEN`

## Workflow Execution

### Branch Push (e.g., `git push origin main`)

```
build-ios ──┐
            ├─→ create-distribution ──→ build-status
build-android ┘
```

**Result:** Artifacts uploaded to GitHub (30-90 day retention)

### Tag Push (e.g., `git tag v0.1.0 && git push --tags`)

```
build-ios ──┐
            ├─→ create-distribution ──→ publish-release ──┐
build-android ┘                                           ├─→ build-status
                                                          │
                                    publish-npm ──────────┘
```

**Result:**
- GitHub Release created with distribution files
- Package published to NPM
- Artifacts available for 90 days

### Pull Request

```
build-ios ──┐
            ├─→ create-distribution ──→ build-status
build-android ┘
```

**Result:** Build validation without publishing

## Manual Workflow Dispatch

Trigger manually from GitHub UI:

1. Go to Actions tab
2. Select "Build and Publish to NPM (Workspace)"
3. Click "Run workflow"
4. Optional: Set publish flags

## Monitoring Builds

### GitHub Actions UI

1. Go to repository → Actions tab
2. Select workflow run
3. View real-time logs
4. Check artifact downloads

### Build Artifacts

**Location:** Actions → Workflow run → Artifacts

**Artifacts:**
- `ios-libraries` (30 days)
- `swift-bindings` (30 days)
- `android-libraries` (30 days)
- `kotlin-bindings` (30 days)
- `distribution-archive` (90 days)

### Releases

**Location:** Releases tab

**Contents:**
- Distribution archive
- SHA256 checksum
- Release notes
- Installation instructions

## Troubleshooting

### iOS Build Fails

**Error:** "target `aarch64-apple-ios` not installed"

**Solution:** Rust targets are installed automatically by the workflow

**Check:** Look for error in build log under "Setup Rust" step

### Android Build Fails

**Error:** "cannot produce cdylib for target"

**Cause:** NDK not properly configured

**Solution:**
1. Check NDK installation in "Verify NDK Installation" step
2. Ensure `ANDROID_NDK_HOME` is set
3. Verify cargo-ndk installation

**Debug:** Add this step to workflow:
```yaml
- name: Debug Android Setup
  run: |
    echo "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
    ls -la $ANDROID_NDK_HOME/
    cargo --version
    rustc --version
```

### NPM Publish Fails

**Error:** "403 Forbidden"

**Cause:** Invalid or expired NPM token

**Solution:**
1. Generate new token at https://www.npmjs.com/settings/tokens
2. Update GitHub Secret: `NPM_TOKEN`
3. Re-run workflow

**Error:** "Package already published"

**Cause:** Version already exists on NPM

**Solution:** Increment version in `package.json` and create new tag

### Distribution Archive Missing

**Error:** "artifact not found"

**Cause:** One or more platform builds failed

**Solution:**
1. Check build-ios and build-android logs
2. Fix compilation errors
3. Re-run workflow

## Performance Optimization

### Caching

The workflow uses `Swatinem/rust-cache@v2` to cache:
- Rust build artifacts
- Dependencies
- Compiled crates

**Cache hits reduce build time by 60-70%**

### Parallel Execution

iOS and Android builds run in parallel:
- Total time ≈ max(iOS time, Android time)
- Not sequential

### Incremental Builds

Subsequent builds are faster:
- First build: 15-20 minutes
- Cached builds: 5-8 minutes

## Release Process

### Creating a Release

1. **Update version:**
   ```bash
   # In react-native-matrix-crypto/package.json
   "version": "0.2.0"
   ```

2. **Commit changes:**
   ```bash
   git add .
   git commit -m "Bump version to 0.2.0"
   git push origin main
   ```

3. **Create tag:**
   ```bash
   git tag v0.2.0
   git push --tags
   ```

4. **Workflow runs automatically:**
   - Builds all platforms
   - Creates GitHub Release
   - Publishes to NPM

5. **Verify:**
   - Check GitHub Releases tab
   - Check NPM: `npm view @k9o/react-native-matrix-crypto`

## Best Practices

### 1. Version Management

- Use semantic versioning: `v0.1.0`, `v1.0.0`, `v1.0.1`
- Update version before creating tag
- Document changes in release notes

### 2. Testing

- Run builds locally before pushing tags
- Test on both macOS (iOS) and Linux (Android)
- Verify artifacts before publishing

### 3. Commits

- Keep commits focused and well-documented
- Use meaningful commit messages
- Reference issues in commits: `Fixes #123`

### 4. Secrets

- Never commit secrets to repository
- Use GitHub Secrets for sensitive data
- Rotate tokens periodically

### 5. Monitoring

- Check workflow runs regularly
- Review build logs for warnings
- Monitor artifact storage usage

## Useful Commands

### View workflow status
```bash
gh workflow list
gh run list --workflow build-and-publish-workspace.yml
```

### Trigger workflow manually
```bash
gh workflow run build-and-publish-workspace.yml
```

### Download artifacts
```bash
gh run download <run-id> -n distribution-archive
```

### View release info
```bash
gh release view v0.1.0
```

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Rust Toolchain Action](https://github.com/dtolnay/rust-toolchain)
- [Android NDK Setup Action](https://github.com/nttld/setup-ndk)
- [NPM Publishing](https://docs.npmjs.com/cli/v9/commands/npm-publish)

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review troubleshooting section
3. Check repository issues
4. Create new issue with logs attached
