# Release and Distribution

Awake distributes public builds through GitHub Releases. The website should link to the stable latest-release asset URL instead of hosting binaries directly.

## Website Download URL

Use this URL for the main download button:

```text
https://github.com/ium-team/Awake/releases/latest/download/Awake.dmg
```

Versioned assets are also uploaded for each release:

```text
https://github.com/ium-team/Awake/releases/download/v0.1.0/Awake-0.1.0.dmg
https://github.com/ium-team/Awake/releases/download/v0.1.0/Awake-0.1.0.zip
```

## Local Release Package

Create release artifacts locally:

```bash
scripts/package-release.sh 0.1.0
```

Artifacts:

- `dist/Awake.dmg`: stable filename for website links and normal macOS installation
- `dist/Awake-0.1.0.dmg`: versioned disk image
- `dist/Awake.zip`: stable archive for advanced/manual installs
- `dist/Awake-0.1.0.zip`: versioned archive
- `dist/checksums.txt`: SHA-256 checksums

The DMG contains `Awake.app` and an `Applications` shortcut so users can install by dragging the app into Applications. It uses a checked-in Finder icon-view layout with fixed icon positions, a native background color, and hidden toolbar/status bar. Packaging does not depend on GUI scripting, so local builds and GitHub Actions create the same installer view.

The DMG is created from an unmounted staging folder instead of a writable mounted disk image. This prevents packaging-time `.background` or `.fseventsd` support folders from being included. The packaging script mounts the finished image read-only and fails if any visible root item besides `Awake.app` and `Applications` is present.

## Create a GitHub Release Locally

Create a draft release:

```bash
scripts/create-github-release.sh 0.1.0 --draft
```

Create a prerelease:

```bash
scripts/create-github-release.sh 0.1.0 --prerelease
```

Create a latest public release:

```bash
scripts/create-github-release.sh 0.1.0 --latest
```

The script requires:

- a clean git working tree
- GitHub CLI authenticated with repository write access
- the target branch pushed to `origin`

## GitHub Actions Release

Run the `Release` workflow manually from GitHub Actions with:

- `version`: for example `0.1.0`
- `mode`: `draft`, `prerelease`, or `latest`

The workflow creates the tag `v<version>` if needed, packages the app, and uploads the release assets.

## Signing and Notarization

Public distribution should use Apple Developer ID signing and notarization. Without it, users may see Gatekeeper warnings.

Local signed package:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="awake-notary" \
scripts/package-release.sh 0.1.0
```

Before running this, create the notarytool keychain profile once:

```bash
xcrun notarytool store-credentials awake-notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

`NOTARY_PROFILE` is optional. If it is omitted, the app is packaged without notarization. If `CODESIGN_IDENTITY` is omitted, the script applies only an ad-hoc signature for local integrity and testing.
