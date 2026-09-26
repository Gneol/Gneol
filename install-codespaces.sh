#!/usr/bin/env bash
# Gneol installer for GitHub Codespaces
# Installs to ~/.local/bin and adds to PATH

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


INSTALL_DIR="$HOME/.local/bin"
REPO="Gneol/Gneol"
VERSION="${GNEOL_VERSION:-v0.2.5}"
ARCHIVE="gneol-linux-x64.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

echo "📦 Installing Gneol ${VERSION} for Codespaces..."
# Check and stop running gneol processes
stop_running_gneol



# Create install directory
mkdir -p "$INSTALL_DIR"

# Download archive to a temp file
TMPFILE="${TMPDIR:-/tmp}/gneol-${VERSION}-$$.tar.gz"
trap 'rm -f "$TMPFILE"' EXIT
echo "⬇️  Downloading ${URL} ..."
if ! curl -fsSL "$URL" -o "$TMPFILE"; then
  echo "❌ Failed to download $URL"
  echo "   Releases: https://github.com/${REPO}/releases"
  exit 1
fi

if ! tar -tzf "$TMPFILE" >/dev/null 2>&1; then
  echo "❌ Downloaded file is not a valid .tar.gz archive."
  exit 1
fi

# Extract
echo "📂 Extracting to ${INSTALL_DIR}..."
tar -xzf "$TMPFILE" -C "$INSTALL_DIR"

if [ ! -f "$INSTALL_DIR/gneol" ]; then
  echo "❌ Extraction finished but no 'gneol' binary found in $INSTALL_DIR"
  exit 1
fi

# Make the binary executable
chmod +x "$INSTALL_DIR/gneol" 2>/dev/null || true

# Ensure ~/.local/bin is in PATH for current and future sessions
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "🔧 Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Clean up
rm -f "$TMPFILE"

echo "✅ Gneol installed successfully!"
echo "   You may need to restart your terminal or run: source ~/.bashrc"
echo "   Run 'gneol --help' to get started."

