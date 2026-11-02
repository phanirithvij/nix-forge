#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Always execute inside the mustang development environment
if [ "${ENV_PACKAGE_NAME:-}" != "mustang" ] && [ -z "${IN_MUSTANG_DEV:-}" ]; then
  exec env IN_MUSTANG_DEV=1 nix develop "$REPO_ROOT#pkgs.mustang.env" --command bash "$0" "$@"
fi

# Upstream Mustang does not ship a yarn.lock in any of app/, desktop/, desktop/backend/, or lib/.
# A synthetic root package.json is used to get a single merged lockfile / fetchYarnDeps cache instead of one per each subdir.
SRC_PATH="${ENV_PACKAGE_SOURCE:-$(nix eval --raw "$REPO_ROOT#pkgs.mustang.src.outPath")}"

TMP_DIR="$(mktemp -d -t mustang-update.XXXXXX)"
cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    chmod -R u+w "$TMP_DIR" 2>/dev/null || true
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT INT TERM HUP

echo "Copying source from $SRC_PATH..."
cp -r --no-preserve=mode,ownership "$SRC_PATH" "$TMP_DIR/src"
chmod -R u+w "$TMP_DIR/src"

# Extract the vite version from upstream's package.json to keep resolution in sync
VITE_VERSION="$(node -p '
  try {
    require("'"$TMP_DIR"'/src/app/package.json").devDependencies.vite
    || require("'"$TMP_DIR"'/src/desktop/package.json").devDependencies.vite
  } catch (e) {
    "^7.3.1"
  }
' 2>/dev/null || echo "^7.3.1")"

echo "Creating synthetic root package.json (with vite: $VITE_VERSION)..."
cat >"$TMP_DIR/src/package.json" <<EOF
{
  "name": "mustang-synthetic-root",
  "private": true,
  "workspaces": [
    "app",
    "desktop",
    "desktop/backend",
    "lib"
  ],
  "resolutions": {
    "vite": "$VITE_VERSION"
  }
}
EOF

if [ -f "$SCRIPT_DIR/yarn.lock" ]; then
  cp "$SCRIPT_DIR/yarn.lock" "$TMP_DIR/src/yarn.lock"
fi

pushd "$TMP_DIR/src" >/dev/null
echo "Updating yarn.lock..."
yarn install --mode=update-lockfile --ignore-scripts
popd >/dev/null

cp "$TMP_DIR/src/yarn.lock" "$SCRIPT_DIR/yarn.lock"
echo "Successfully updated $SCRIPT_DIR/yarn.lock"
