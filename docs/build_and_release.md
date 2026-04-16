# Build and Release Guide

This project uses GitHub Actions for CI and tagged releases.

## CI Workflow

The CI workflow (`.github/workflows/ci.yml`) runs on push and pull requests:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

## Tagged Release Workflow

The release workflow (`.github/workflows/release.yml`) runs when pushing a tag matching:

```text
v*.*.*
```

### Artifacts Produced

- Android APK (`flutter build apk --release`)
- Windows desktop bundle (`flutter build windows --release`)

Artifacts are uploaded to the workflow run and attached to the GitHub Release.

## Local Build Commands

Run from repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```

On macOS hosts:

```powershell
flutter build macos --release
```

## Creating a Release

1. Ensure CI is green on the main branch.
2. Create and push a semantic version tag:

   ```powershell
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. Wait for the `release` workflow to complete.
4. Verify generated release assets on GitHub.
