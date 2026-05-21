#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/create-github-release.sh <version> [--draft|--prerelease]" >&2
  exit 1
fi

RELEASE_MODE="${2:---draft}"
if [[ "$RELEASE_MODE" != "--draft" && "$RELEASE_MODE" != "--prerelease" && "$RELEASE_MODE" != "--latest" ]]; then
  echo "Release mode must be --draft, --prerelease, or --latest." >&2
  exit 1
fi

cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI 'gh' is required." >&2
  exit 1
fi

gh auth status >/dev/null

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit changes before creating a release." >&2
  exit 1
fi

TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally." >&2
else
  git tag -a "$TAG" -m "Release $TAG"
fi

git push origin "$(git branch --show-current)"
git push origin "$TAG"

scripts/package-release.sh "$VERSION"

NOTES_FILE="$(mktemp)"
cat > "$NOTES_FILE" <<NOTES
Awake $VERSION

Download:
- Awake.zip: stable asset name for website links
- Awake-$VERSION.zip: versioned archive

Website latest-download URL:
https://github.com/ium-team/Awake/releases/latest/download/Awake.zip
NOTES

FLAGS=()
case "$RELEASE_MODE" in
  --draft) FLAGS+=(--draft) ;;
  --prerelease) FLAGS+=(--prerelease) ;;
  --latest) FLAGS+=(--latest) ;;
esac

gh release create "$TAG" \
  dist/Awake.zip \
  "dist/Awake-$VERSION.zip" \
  dist/checksums.txt \
  --title "Awake $VERSION" \
  --notes-file "$NOTES_FILE" \
  "${FLAGS[@]}"

rm -f "$NOTES_FILE"

echo "Release created for $TAG."
