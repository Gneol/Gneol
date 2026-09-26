#!/bin/bash

# Gneol Installer
# Downloads the correct platform archive (tar.gz) containing the single Gneol binary (CLI + LLM + terminal)

set -e

# Function to stop running gneol processes
stop_running_gneol() {
  local pids
  pids=$(pgrep -x gneol 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "⚠️  Gneol is currently running (PID(s): $pids)."
    echo "   To avoid file locks during installation, running instances should be stopped."
    if [ -t 0 ]; then
      read -p "   Stop all running gneol processes? [Y/n] " -r response
    elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
      # stdin is a pipe (curl | bash) - prompt on the real terminal instead,
      # with a timeout so a headless/CI run can never hang forever.
      read -t 15 -p "   Stop all running gneol processes? [Y/n] " -r response < /dev/tty || response=""
    else
      echo "   Non-interactive install detected; proceeding to stop running processes."
      response="y"
    fi
    case "$response" in
      [nN]|[nN][oO])
        echo "❌ Installation aborted. Please stop gneol manually and try again."
        exit 1
        ;;
      *)
        echo "🛑 Stopping gneol..."
        pkill -x gneol 2>/dev/null || true
        sleep 1
        if pgrep -x gneol >/dev/null 2>&1; then
          echo "   Force stopping remaining processes..."
          pkill -x -9 gneol 2>/dev/null || true
        fi
        echo "✅ All gneol processes stopped."
        ;;
    esac
  fi
}


REPO="Gneol/Gneol"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--version <tag>] [--dir <path>]"
      exit 1
      ;;
  esac
done

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize arch and set archive name
case "$ARCH" in
  x86_64) ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="linux-x64" ;;
  darwin) PLATFORM="darwin-arm64" ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

ARCHIVE="gneol-${PLATFORM}.tar.gz"

if [ "$VERSION" = "latest" ]; then
  BASE_URL="https://github.com/$REPO/releases/latest/download"
else
  BASE_URL="https://github.com/$REPO/releases/download/$VERSION"
fi

echo "📦 Downloading Gneol for $PLATFORM..."
# Check and stop running gneol processes
stop_running_gneol


echo ""

TMP_ARCHIVE="${TMPDIR:-/tmp}/gneol-${PLATFORM}-$$.tar.gz"
trap 'rm -f "$TMP_ARCHIVE"' EXIT

# Create install directory if needed
if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
  echo "❌ Cannot create install directory: $INSTALL_DIR"
  echo "   Re-run with sudo, or pick a writable dir: $0 --dir "$HOME/.local/bin""
  exit 1
fi
if [ ! -w "$INSTALL_DIR" ]; then
  echo "❌ No write permission for $INSTALL_DIR"
  echo "   Re-run with sudo, or pick a writable dir: $0 --dir "$HOME/.local/bin""
  exit 1
fi

# Download archive
ARCHIVE_URL="$BASE_URL/$ARCHIVE"
echo "  → $ARCHIVE"
if ! curl -fsSL "$ARCHIVE_URL" -o "$TMP_ARCHIVE"; then
  echo "❌ Failed to download $ARCHIVE_URL"
  echo "   Verify release "$VERSION" exists and ships $ARCHIVE."
  echo "   Releases: https://github.com/$REPO/releases"
  exit 1
fi

# Validate the download before touching the install dir
if ! tar -tzf "$TMP_ARCHIVE" >/dev/null 2>&1; then
  echo "❌ Downloaded file is not a valid .tar.gz archive: $ARCHIVE"
  exit 1
fi

# Extract archive into install directory
tar -xzf "$TMP_ARCHIVE" -C "$INSTALL_DIR"

# Verify the binary actually landed
if [ ! -f "$INSTALL_DIR/gneol" ]; then
  echo "❌ Extraction finished but no 'gneol' binary found in $INSTALL_DIR"
  exit 1
fi

# Set permissions
chmod +x "$INSTALL_DIR/gneol"

echo ""
echo "✅ Gneol installed!"
echo "   gneol              → $INSTALL_DIR/gneol"
echo ""
echo "Run 'gneol --help' to get started."
