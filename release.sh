#!/usr/bin/env bash
set -euo pipefail

# release.sh — Calculate and create the next release tag
#
# This script looks up the latest semantic version tag (vX.Y.Z)
# from the upstream repo Fyve-Labs/wifi-provisioner, calculates the
# next version according to the requested bump (patch|minor|major),
# then optionally tags the current repository and pushes the tag to origin.
#
# Usage:
#   ./release.sh [patch|minor|major] [-y] [--no-push] [--dry-run]
#
# Defaults:
#   bump = patch
#   confirm before tagging/pushing unless -y is given
#
# Examples:
#   ./release.sh            # bump patch from upstream latest
#   ./release.sh minor -y   # bump minor and push without confirmation
#   ./release.sh major --dry-run   # show what would happen
#

UPSTREAM_REPO_URL="https://github.com/Fyve-Labs/wifi-provisioner.git"
BUMP="patch"
ASSUME_YES="false"
NO_PUSH="false"
DRY_RUN="false"

while (( "$#" )); do
  case "$1" in
    patch|minor|major)
      BUMP="$1";
      shift ;;
    -y|--yes)
      ASSUME_YES="true"; shift ;;
    --no-push)
      NO_PUSH="true"; shift ;;
    -n|--dry-run)
      DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '1,80p' "$0"; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Fetch latest tag from upstream repo
# We sort by version (descending) and pick the first matching v* tag.
LATEST_TAG=$(git ls-remote --tags --sort=-v:refname "$UPSTREAM_REPO_URL" 'v[0-9]*.[0-9]*.[0-9]*' \
  | awk '{print $2}' \
  | sed -E 's#\^\{\}$##' \
  | head -n1)

if [[ -z "${LATEST_TAG}" ]]; then
  echo "No existing tags found in upstream. Defaulting to v0.0.0" >&2
  LATEST_TAG="refs/tags/v0.0.0"
fi

# Extract tag name (strip refs/tags/)
LATEST_TAG_NAME=${LATEST_TAG#refs/tags/}

# Strip leading v and split into components
VERSION=${LATEST_TAG_NAME#v}
IFS='.' read -r MAJOR MINOR PATCH <<<"$VERSION"

# Fallbacks if parse failed
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

case "$BUMP" in
  patch)
    PATCH=$((PATCH + 1)) ;;
  minor)
    MINOR=$((MINOR + 1)); PATCH=0 ;;
  major)
    MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  *)
    echo "Invalid bump type: $BUMP" >&2; exit 1 ;;
fi

NEXT_TAG="v${MAJOR}.${MINOR}.${PATCH}"

echo "Upstream latest tag: ${LATEST_TAG_NAME}"
echo "Requested bump:      ${BUMP}"
echo "Next tag to release: ${NEXT_TAG}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run enabled. No tag will be created or pushed."
  exit 0
fi

# Verify we are on a clean working tree to avoid accidental tagging
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree has uncommitted changes. Please commit or stash before releasing." >&2
  exit 1
fi

# Confirm
if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Create and push tag ${NEXT_TAG} to origin? [y/N] " REPLY
  case "$REPLY" in
    y|Y|yes|YES) : ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# Create annotated tag
if git rev-parse "$NEXT_TAG" >/dev/null 2>&1; then
  echo "Tag $NEXT_TAG already exists locally." >&2
else
  echo "Creating tag $NEXT_TAG ..."
  git tag -a "$NEXT_TAG" -m "Release $NEXT_TAG"
fi

# Push tag
if [[ "$NO_PUSH" == "true" ]]; then
  echo "--no-push specified. Not pushing tag."
  exit 0
fi

echo "Pushing tag $NEXT_TAG to origin ..."
git push origin "$NEXT_TAG"

echo "Done. GitHub Actions (if configured) should create a release for $NEXT_TAG."