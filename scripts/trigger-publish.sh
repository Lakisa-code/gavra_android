#!/usr/bin/env bash
set -euo pipefail

TAG_NAME=${1:-v$(date +%Y%m%d%H%M%S)}
MSG=${2:-"Automated publish from CI"}

echo "Creating annotated tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "$MSG"
git push origin "$TAG_NAME"

echo "Tag pushed — CI publish workflow should start for tag $TAG_NAME."
