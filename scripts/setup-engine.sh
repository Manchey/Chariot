#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Xiangqi/Resources"
TMPDIR_BUILD="$(mktemp -d)"

cleanup() { rm -rf "$TMPDIR_BUILD"; }
trap cleanup EXIT

echo "==> Setting up Pikafish engine for Chariot"
echo ""

mkdir -p "$RESOURCES_DIR"

# 1. Build pikafish binary from source
if [ -f "$RESOURCES_DIR/pikafish" ]; then
    echo "[skip] pikafish binary already exists"
else
    echo "[1/2] Building pikafish from source..."
    if ! command -v make &>/dev/null || ! command -v git &>/dev/null; then
        echo "Error: git and make are required. Install Xcode Command Line Tools:"
        echo "  xcode-select --install"
        exit 1
    fi
    git clone --depth 1 https://github.com/official-pikafish/Pikafish.git "$TMPDIR_BUILD/Pikafish"
    make -C "$TMPDIR_BUILD/Pikafish/src" -j "$(sysctl -n hw.ncpu)" build ARCH=apple-silicon COMP=clang
    cp "$TMPDIR_BUILD/Pikafish/src/pikafish" "$RESOURCES_DIR/pikafish"
    chmod +x "$RESOURCES_DIR/pikafish"
    echo "  -> pikafish binary built and copied"
fi

# 2. Download NNUE weights
if [ -f "$RESOURCES_DIR/pikafish.nnue" ]; then
    echo "[skip] pikafish.nnue already exists"
else
    echo "[2/2] Downloading NNUE weights..."
    # Get the latest release NNUE file URL from GitHub API
    NNUE_URL=$(curl -sL https://api.github.com/repos/official-pikafish/Pikafish/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*\.nnue"' \
        | head -1 \
        | sed 's/"browser_download_url": *"//;s/"$//')
    if [ -z "$NNUE_URL" ]; then
        echo "Error: Could not find NNUE download URL from GitHub releases."
        echo "Please download manually from:"
        echo "  https://github.com/official-pikafish/Pikafish/releases"
        echo "and place the .nnue file at: $RESOURCES_DIR/pikafish.nnue"
        exit 1
    fi
    curl -L --progress-bar -o "$RESOURCES_DIR/pikafish.nnue" "$NNUE_URL"
    echo "  -> pikafish.nnue downloaded"
fi

echo ""
echo "==> Done! Open Xiangqi.xcodeproj in Xcode and build."
