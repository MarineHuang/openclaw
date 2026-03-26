#!/bin/bash
set -euo pipefail

# Build an all-in-one offline package for OpenClaw.
# Run this on a machine with network access, pnpm, and Node.js installed.
# The resulting archive can be transferred to an air-gapped machine —
# no Node.js, npm, or internet required to run.
#
# Usage:
#   bash offline/build.sh [--target <platform>] [--node-version <ver>]
#
# Options:
#   --target        Target platform: win-x64, linux-x64, linux-arm64,
#                   darwin-x64, darwin-arm64  (default: auto-detect host)
#   --node-version  Node.js version to bundle (default: 22.14.0)
#   --skip-build    Skip pnpm install / build steps (use existing dist/)
#   --no-compress   Leave output as a directory; skip zip/tar creation
#                   (useful for local debugging and inspection)
#   --output-dir    Directory for the final output (default: ./offline-dist)
#   -h, --help      Show this help message

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

print_help() {
    cat << 'EOF'
Build an all-in-one offline package for OpenClaw.
Run this on a machine with network access, pnpm, and Node.js installed.
The resulting archive can be transferred to an air-gapped machine —
no Node.js, npm, or internet required to run.

Usage:
  bash offline/build.sh [--target <platform>] [--node-version <ver>]

Options:
  --target        Target platform: win-x64, linux-x64, linux-arm64,
                  darwin-x64, darwin-arm64  (default: auto-detect host)
  --node-version  Node.js version to bundle (default: 22.14.0)
  --skip-build    Skip pnpm install / build steps (use existing dist/)
  --no-compress   Leave output as a plain directory; skip zip/tar creation
                  (useful for local debugging: inspect files without extracting)
  --output-dir    Directory for the final output (default: ./offline-dist)
  -h, --help      Show this help message
EOF
}

# ── Defaults ──────────────────────────────────────────────────────
NODE_VERSION="22.22.1"
TARGET=""
SKIP_BUILD=false
NO_COMPRESS=false
OUTPUT_DIR="$PROJECT_ROOT/offline/dist"

# ── Parse arguments ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)       TARGET="$2"; shift 2 ;;
        --node-version) NODE_VERSION="$2"; shift 2 ;;
        --skip-build)   SKIP_BUILD=true; shift ;;
        --no-compress)  NO_COMPRESS=true; shift ;;
        --output-dir)   OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Auto-detect target platform ──────────────────────────────────
if [[ -z "$TARGET" ]]; then
    HOST_OS="$(uname -s 2>/dev/null || true)"
    HOST_ARCH="$(uname -m 2>/dev/null || true)"

    case "$HOST_OS" in
        Linux)  OS_PART="linux" ;;
        Darwin) OS_PART="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) OS_PART="win" ;;
        *)      echo "ERROR: Cannot auto-detect OS ($HOST_OS). Use --target."; exit 1 ;;
    esac

    case "$HOST_ARCH" in
        x86_64|amd64)   ARCH_PART="x64" ;;
        arm64|aarch64)  ARCH_PART="arm64" ;;
        *)              echo "ERROR: Cannot auto-detect arch ($HOST_ARCH). Use --target."; exit 1 ;;
    esac

    TARGET="${OS_PART}-${ARCH_PART}"
fi

# ── Validate target ──────────────────────────────────────────────
case "$TARGET" in
    win-x64|linux-x64|linux-arm64|darwin-x64|darwin-arm64) ;;
    *) echo "ERROR: Unsupported target: $TARGET"; exit 1 ;;
esac

# Split target into OS and arch
TARGET_OS="${TARGET%%-*}"

# Map build target → koffi platform directory name
case "$TARGET" in
    win-x64)      KOFFI_PLATFORM="win32_x64" ;;
    linux-x64)    KOFFI_PLATFORM="linux_x64" ;;
    linux-arm64)  KOFFI_PLATFORM="linux_arm64" ;;
    darwin-x64)   KOFFI_PLATFORM="darwin_x64" ;;
    darwin-arm64) KOFFI_PLATFORM="darwin_arm64" ;;
esac

# Map build target → npm --os / --cpu flags for optional native deps.
# npm 10+ installs only optional packages matching the specified platform,
# so cross-compiling (e.g. building win-x64 on Linux) works correctly.
case "$TARGET" in
    win-x64)      NPM_OS="win32"  ; NPM_CPU="x64"   ;;
    linux-x64)    NPM_OS="linux"  ; NPM_CPU="x64"   ;;
    linux-arm64)  NPM_OS="linux"  ; NPM_CPU="arm64" ;;
    darwin-x64)   NPM_OS="darwin" ; NPM_CPU="x64"   ;;
    darwin-arm64) NPM_OS="darwin" ; NPM_CPU="arm64" ;;
esac

# ── Derive Node.js download URL ──────────────────────────────────
NODE_BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}"
case "$TARGET" in
    win-x64)       NODE_ARCHIVE="node-v${NODE_VERSION}-win-x64.zip" ;;
    linux-x64)     NODE_ARCHIVE="node-v${NODE_VERSION}-linux-x64.tar.xz" ;;
    linux-arm64)   NODE_ARCHIVE="node-v${NODE_VERSION}-linux-arm64.tar.xz" ;;
    darwin-x64)    NODE_ARCHIVE="node-v${NODE_VERSION}-darwin-x64.tar.gz" ;;
    darwin-arm64)  NODE_ARCHIVE="node-v${NODE_VERSION}-darwin-arm64.tar.gz" ;;
esac
NODE_URL="${NODE_BASE_URL}/${NODE_ARCHIVE}"

# Read version from package.json
VERSION="$(node -p "require('$PROJECT_ROOT/package.json').version")"
PACKAGE_NAME="openclaw-offline-${VERSION}-${TARGET}"

echo "============================================"
echo " OpenClaw Offline Package Builder"
echo "============================================"
echo " Version:      $VERSION"
echo " Target:       $TARGET"
echo " Node.js:      v$NODE_VERSION"
echo " Compress:     $([ "$NO_COMPRESS" == true ] && echo no || echo yes)"
echo " Output:       $OUTPUT_DIR/$PACKAGE_NAME"
echo "============================================"
echo ""

# ── Step 1: Build project ────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    echo "[1/5] Installing dependencies..."
    (cd "$PROJECT_ROOT" && pnpm install --frozen-lockfile)

    echo ""
    echo "[2/5] Building project..."
    (cd "$PROJECT_ROOT" && pnpm build)

    echo ""
    echo "[3/5] Building Dashboard UI..."
    (cd "$PROJECT_ROOT" && pnpm ui:build)
else
    echo "[1-3/5] Skipping build (--skip-build)"
fi

# ── Step 2: Download Node.js ─────────────────────────────────────
echo ""
echo "[4/5] Downloading Node.js v${NODE_VERSION} for ${TARGET}..."

CACHE_DIR="$PROJECT_ROOT/.offline-cache"
mkdir -p "$CACHE_DIR"

NODE_CACHED="$CACHE_DIR/$NODE_ARCHIVE"
if [[ -f "$NODE_CACHED" ]]; then
    echo "  Using cached: $NODE_CACHED"
else
    echo "  Downloading: $NODE_URL"
    curl -fSL --retry 3 --retry-delay 2 -o "$NODE_CACHED" "$NODE_URL"
fi

# ── Step 3: Assemble staging directory ───────────────────────────
echo ""
echo "[5/5] Assembling offline package..."

STAGING="$OUTPUT_DIR/.staging-${TARGET}"
rm -rf "$STAGING"
mkdir -p "$STAGING"

# Extract Node.js binary into node-runtime/
NODE_EXTRACT_TMP="$STAGING/.node-extract"
mkdir -p "$NODE_EXTRACT_TMP"

if [[ "$TARGET_OS" == "win" ]]; then
    # Windows zip
    unzip -q "$NODE_CACHED" -d "$NODE_EXTRACT_TMP"
    mkdir -p "$STAGING/node-runtime"
    cp "$NODE_EXTRACT_TMP"/node-v*/node.exe "$STAGING/node-runtime/node.exe"
else
    # Linux/macOS tar
    tar -xf "$NODE_CACHED" -C "$NODE_EXTRACT_TMP"
    mkdir -p "$STAGING/node-runtime/bin"
    cp "$NODE_EXTRACT_TMP"/node-v*/bin/node "$STAGING/node-runtime/bin/node"
    chmod +x "$STAGING/node-runtime/bin/node"
fi
rm -rf "$NODE_EXTRACT_TMP"

# Copy project files (mirror what Dockerfile copies to runtime)
cp "$PROJECT_ROOT/openclaw.mjs" "$STAGING/"
cp "$PROJECT_ROOT/package.json" "$STAGING/"

# dist/ — compiled output
if [[ ! -d "$PROJECT_ROOT/dist" ]]; then
    echo "ERROR: dist/ not found. Run build first (remove --skip-build)."
    exit 1
fi
# Copy dist/ (plugin-sdk is needed at runtime for extensions)
cp -r "$PROJECT_ROOT/dist" "$STAGING/dist"

# node_modules/ — production dependencies only
echo "  Collecting production dependencies..."

# Install in a temp dir *outside* the project root so pnpm does not pick up
# pnpm-workspace.yaml and treats it as a standalone package.
PROD_TMP="$(mktemp -d)"
cp "$PROJECT_ROOT/package.json" "$PROD_TMP/"
[[ -f "$PROJECT_ROOT/pnpm-lock.yaml" ]] && cp "$PROJECT_ROOT/pnpm-lock.yaml" "$PROD_TMP/"

# Use npm (not pnpm) so node_modules is a flat real-directory tree with no
# symlinks and no .pnpm virtual store.  Symlinks break on Windows unless the
# user has Developer Mode / admin rights, so we must avoid them.
# --os / --cpu tell npm which platform's optional native packages to install,
# enabling correct cross-platform builds (e.g. building win-x64 on Linux).
# Helper: recursively resolve pnpm symlinks into real directories.
# This is necessary because pnpm uses a virtual store (.pnpm) with symlinks
# pointing to it, and these symlinks don't work on Windows without Developer Mode.
resolve_pnpm_symlinks() {
    local dir="$1"
    echo "  Resolving pnpm symlinks for Windows compatibility..."
    # Keep resolving until no more symlinks are found (handles nested symlinks)
    local iteration=0
    local symlinks_file
    symlinks_file="$(mktemp)"
    while true; do
        find "$dir/node_modules" -type l 2>/dev/null > "$symlinks_file"
        if [[ ! -s "$symlinks_file" ]]; then
            break
        fi
        iteration=$((iteration + 1))
        if [[ $iteration -gt 20 ]]; then
            echo "  WARNING: Too many symlink resolution iterations, stopping."
            break
        fi
        local count=0
        while IFS= read -r link; do
            local target
            target="$(readlink -f "$link" 2>/dev/null)" || continue
            [[ -d "$target" ]] || continue
            rm "$link"
            cp -r "$target" "$link"
            count=$((count + 1))
        done < "$symlinks_file"
        echo "    Iteration $iteration: resolved $count symlinks"
    done
    rm -f "$symlinks_file"
    # Remove .pnpm virtual store after resolving all symlinks
    rm -rf "$dir/node_modules/.pnpm"
}

if command -v npm &>/dev/null && \
   (cd "$PROD_TMP" && npm install --omit=dev \
      --os="$NPM_OS" --cpu="$NPM_CPU" \
      --ignore-scripts --prefer-offline --no-audit --no-fund \
      2>/dev/null) && \
   [[ -d "$PROD_TMP/node_modules" ]]; then
    cp -r "$PROD_TMP/node_modules" "$STAGING/node_modules"
elif (cd "$PROD_TMP" && pnpm install --prod --no-optional --ignore-scripts 2>/dev/null) && \
   [[ -d "$PROD_TMP/node_modules" ]]; then
    cp -r "$PROD_TMP/node_modules" "$STAGING/node_modules"
    resolve_pnpm_symlinks "$STAGING"
else
    # Last-resort fallback: copy full node_modules and strip caches
    echo "  WARNING: npm/pnpm install failed, falling back to full node_modules copy + prune..."
    cp -r "$PROJECT_ROOT/node_modules" "$STAGING/node_modules"
    resolve_pnpm_symlinks "$STAGING"
    find "$STAGING/node_modules" -name ".cache" -type d -exec rm -rf {} + 2>/dev/null || true
fi
rm -rf "$PROD_TMP"

# ── Prune native addon prebuilds to target platform only ──────────
echo "  Pruning non-target native prebuilds..."

# koffi bundles all 18 platform binaries in one package; keep only the target.
# Support both npm flat layout (node_modules/koffi) and pnpm virtual store (.pnpm).
for koffi_base in \
    "$STAGING/node_modules/koffi/build/koffi" \
    "$STAGING/node_modules/.pnpm/koffi@"*/node_modules/koffi/build/koffi; do
    [[ -d "$koffi_base" ]] || continue
    for platform_dir in "$koffi_base"/*/; do
        dir_name="$(basename "$platform_dir")"
        if [[ "$dir_name" != "$KOFFI_PLATFORM" ]]; then
            rm -rf "$platform_dir"
        fi
    done
done

# Remove source maps from node_modules (not needed at runtime, saves ~8 MB).
find "$STAGING/node_modules" -name "*.map" -delete 2>/dev/null || true

# Additional project directories
for dir in extensions skills docs; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        cp -r "$PROJECT_ROOT/$dir" "$STAGING/$dir"
    fi
done

if [[ -d "$PROJECT_ROOT/assets" ]]; then
    cp -r "$PROJECT_ROOT/assets" "$STAGING/assets"
fi

# ── Copy startup scripts from offline/ ───────────────────────────
# Scripts live in offline/ so they can be edited independently of this build script.
cp "$SCRIPT_DIR/start.bat" "$STAGING/start.bat"
cp "$SCRIPT_DIR/start.ps1" "$STAGING/start.ps1"
cp "$SCRIPT_DIR/start.sh"  "$STAGING/start.sh"
chmod +x "$STAGING/start.sh"
cp "$SCRIPT_DIR/README.md" "$STAGING/README.md"

# Copy default providers config and main config template
cp "$SCRIPT_DIR/openclaw-providers.json" "$STAGING/openclaw-providers.json"
cp "$SCRIPT_DIR/openclaw-main.json"      "$STAGING/openclaw-main.json"

# Pre-install QQ Bot plugin for offline use
# We npm-pack the real @tencent-connect/openclaw-qqbot package so the extension
# dir contains the plugin's own package.json (with openclaw.extensions) and
# openclaw.plugin.json, which is what the OpenClaw plugin scanner requires.
echo "  Pre-installing QQ Bot plugin (@tencent-connect/openclaw-qqbot)..."
QQBOT_PLUGIN_DIR="$STAGING/plugins/openclaw-qqbot"
QQBOT_TMP=$(mktemp -d)
QQBOT_OK=false
if (cd "$QQBOT_TMP" && npm pack @tencent-connect/openclaw-qqbot --quiet 2>/dev/null); then
    QQBOT_TARBALL=$(ls "$QQBOT_TMP"/*.tgz 2>/dev/null | head -1)
    if [ -n "$QQBOT_TARBALL" ]; then
        mkdir -p "$QQBOT_PLUGIN_DIR"
        # npm pack tarballs have a top-level "package/" directory; strip it.
        # @tencent-connect/openclaw-qqbot already bundles its node_modules in
        # the tarball, so no separate npm install step is needed.
        tar xzf "$QQBOT_TARBALL" --strip-components=1 -C "$QQBOT_PLUGIN_DIR" 2>/dev/null && \
            QQBOT_OK=true
    fi
fi
rm -rf "$QQBOT_TMP"
if [ "$QQBOT_OK" = false ]; then
    rm -rf "$QQBOT_PLUGIN_DIR"
    echo "  WARNING: qqbot plugin pre-install failed; users will need to install manually."
else
    echo "  QQ Bot plugin pre-installed successfully."
fi

# Pre-install Feishu (Lark) official plugin for offline use
echo "  Pre-installing Feishu plugin (@openclaw/feishu)..."
FEISHU_PLUGIN_DIR="$STAGING/plugins/feishu"
FEISHU_TMP=$(mktemp -d)
FEISHU_OK=false
if (cd "$FEISHU_TMP" && npm pack @openclaw/feishu --quiet 2>/dev/null); then
    FEISHU_TARBALL=$(ls "$FEISHU_TMP"/*.tgz 2>/dev/null | head -1)
    if [ -n "$FEISHU_TARBALL" ]; then
        mkdir -p "$FEISHU_PLUGIN_DIR"
        tar xzf "$FEISHU_TARBALL" --strip-components=1 -C "$FEISHU_PLUGIN_DIR" 2>/dev/null && \
            FEISHU_OK=true
        if [ "$FEISHU_OK" = true ]; then
            # Install plugin dependencies (omit dev)
            (cd "$FEISHU_PLUGIN_DIR" && npm install --omit=dev --ignore-scripts \
                --no-audit --no-fund --legacy-peer-deps --quiet 2>/dev/null) || true
        fi
    fi
fi
rm -rf "$FEISHU_TMP"
if [ "$FEISHU_OK" = false ]; then
    rm -rf "$FEISHU_PLUGIN_DIR"
    echo "  WARNING: Feishu plugin pre-install failed; users will need to install manually."
else
    echo "  Feishu plugin pre-installed successfully."
    # Replace pnpm symlinks in extensions/feishu/node_modules with real npm-installed
    # copies from the pre-installed plugin. The copied extensions/feishu/node_modules
    # contains symlinks into the pnpm virtual store (.pnpm), which don't exist in
    # the offline package. Using the npm-installed copies from plugins/feishu avoids
    # broken-symlink failures when the plugin loads at runtime.
    if [[ -d "$STAGING/extensions/feishu" && -d "$FEISHU_PLUGIN_DIR/node_modules" ]]; then
        rm -rf "$STAGING/extensions/feishu/node_modules"
        cp -r "$FEISHU_PLUGIN_DIR/node_modules" "$STAGING/extensions/feishu/node_modules"
        echo "  Feishu extension node_modules replaced with real npm copies (pnpm symlinks removed)."
    fi
fi

# Pre-install WeChat (Weixin) official plugin for offline use
echo "  Pre-installing Weixin plugin (@tencent-weixin/openclaw-weixin)..."
WEIXIN_PLUGIN_DIR="$STAGING/plugins/openclaw-weixin"
WEIXIN_TMP=$(mktemp -d)
WEIXIN_OK=false
if (cd "$WEIXIN_TMP" && npm pack @tencent-weixin/openclaw-weixin --quiet 2>/dev/null); then
    WEIXIN_TARBALL=$(ls "$WEIXIN_TMP"/*.tgz 2>/dev/null | head -1)
    if [ -n "$WEIXIN_TARBALL" ]; then
        mkdir -p "$WEIXIN_PLUGIN_DIR"
        tar xzf "$WEIXIN_TARBALL" --strip-components=1 -C "$WEIXIN_PLUGIN_DIR" 2>/dev/null && \
            WEIXIN_OK=true
        if [ "$WEIXIN_OK" = true ]; then
            # Install plugin dependencies (omit dev)
            (cd "$WEIXIN_PLUGIN_DIR" && npm install --omit=dev --ignore-scripts \
                --no-audit --no-fund --legacy-peer-deps --quiet 2>/dev/null) || true
        fi
    fi
fi
rm -rf "$WEIXIN_TMP"
if [ "$WEIXIN_OK" = false ]; then
    rm -rf "$WEIXIN_PLUGIN_DIR"
    echo "  WARNING: Weixin plugin pre-install failed; users will need to install manually."
else
    echo "  Weixin plugin pre-installed successfully."
fi

# ── Step 4: Create archive (or leave as directory) ───────────────
echo ""
mkdir -p "$OUTPUT_DIR"

FINAL_DIR="$OUTPUT_DIR/$PACKAGE_NAME"
rm -rf "$FINAL_DIR"
mv "$STAGING" "$FINAL_DIR"

if [[ "$NO_COMPRESS" == true ]]; then
    echo "============================================"
    echo " Build complete! (no-compress mode)"
    echo "============================================"
    echo " Directory: $FINAL_DIR"
    echo ""
    echo " To inspect:"
    echo "   ls $FINAL_DIR"
    echo "============================================"
    exit 0
fi

echo "Creating archive..."

if [[ "$TARGET_OS" == "win" ]]; then
    ARCHIVE_FILE="$OUTPUT_DIR/${PACKAGE_NAME}.zip"
    if command -v zip &>/dev/null; then
        (cd "$OUTPUT_DIR" && zip -rq "${PACKAGE_NAME}.zip" "$PACKAGE_NAME")
        echo "  Created: $ARCHIVE_FILE"
    else
        echo "ERROR: 'zip' command not found; cannot create Windows package."
        rm -rf "$FINAL_DIR"
        exit 1
    fi
else
    ARCHIVE_FILE="$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz"
    (cd "$OUTPUT_DIR" && tar czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME")
    echo "  Created: $ARCHIVE_FILE"
fi

# Clean up the uncompressed staging directory
rm -rf "$FINAL_DIR"

echo ""
echo "============================================"
echo " Build complete!"
echo "============================================"
ARCHIVE_SIZE="$(du -sh "$ARCHIVE_FILE" | cut -f1)"
echo " Archive:  $ARCHIVE_FILE"
echo " Size:     $ARCHIVE_SIZE"
echo ""
echo " To use:"
echo "   1. Copy the archive to the target machine"
if [[ "$TARGET_OS" == "win" ]]; then
    echo "   2. Extract the .zip and double-click start.bat"
else
    echo "   2. Extract: tar xzf ${PACKAGE_NAME}.tar.gz"
    echo "   3. Run: cd $PACKAGE_NAME && ./start.sh"
fi
echo "============================================"
