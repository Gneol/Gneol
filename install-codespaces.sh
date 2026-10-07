#!/usr/bin/env bash
# Gneol installer for GitHub Codespaces
# Installs to ~/.local/bin and adds to PATH

set -e

# Function to stop running gneol processes
stop_running_gneol() {
  local pids
  pids=$(pgrep -x gneol 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "gneol is running (PID(s): $pids)"
    if [ -t 0 ]; then
      read -p "Stop running gneol processes? [Y/n] " -r response
    elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
      # stdin is a pipe (curl | bash) - prompt on the real terminal instead,
      # with a timeout so a headless/CI run can never hang forever.
      read -t 15 -p "Stop running gneol processes? [Y/n] " -r response < /dev/tty || response=""
    else
      response="y"
    fi
    case "$response" in
      [nN]|[nN][oO])
        echo "Installation aborted. Stop gneol manually and try again."
        exit 1
        ;;
      *)
        echo "Stopping gneol..."
        pkill -x gneol 2>/dev/null || true
        sleep 1
        if pgrep -x gneol >/dev/null 2>&1; then
          pkill -x -9 gneol 2>/dev/null || true
        fi
        echo "gneol stopped."
        ;;
    esac
  fi
}

# Download a file, rendering an ASCII progress bar on a TTY.
download_with_progress() {
  local url="$1" out="$2"
  local width=28
  local full empty total size pct filled prev rc

  full=$(printf '%*s' "$width" '' | tr ' ' '#')
  empty=$(printf '%*s' "$width" '' | tr ' ' '-')

  # Non-interactive (curl | bash into a pipe, CI): no animation.
  if [ ! -t 1 ]; then
    curl -fsSL "$url" -o "$out"
    return $?
  fi

  total=$(curl -sIL "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v+0}')
  [ -z "$total" ] && total=0

  curl -fsSL "$url" -o "$out" &
  local dlpid=$!

  prev=-1
  while kill -0 "$dlpid" 2>/dev/null; do
    size=0
    if [ -f "$out" ]; then
      size=$(wc -c < "$out" 2>/dev/null | tr -d '[:space:]')
      [ -z "$size" ] && size=0
    fi
    if [ "$total" -gt 0 ]; then
      pct=$(( size * 100 / total ))
      [ "$pct" -gt 100 ] && pct=100
    else
      pct=0
    fi
    if [ "$pct" != "$prev" ]; then
      filled=$(( pct * width / 100 ))
      printf '\r  [%s%s] %3d%%' "${full:0:filled}" "${empty:0:$(( width - filled ))}" "$pct"
      prev=$pct
    fi
    sleep 0.2
  done

  rc=0
  wait "$dlpid" || rc=$?

  if [ "$rc" -eq 0 ]; then
    printf '\r  [%s] 100%%\n' "$full"
  else
    printf '\n'
  fi
  return "$rc"
}


INSTALL_DIR="$HOME/.local/bin"
REPO="Gneol/Gneol"
VERSION="${GNEOL_VERSION:-v0.2.5}"
ARCHIVE="gneol-linux-x64.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

echo "Installing gneol ${VERSION} for Codespaces..."
stop_running_gneol

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download archive to a temp file
TMPFILE="${TMPDIR:-/tmp}/gneol-${VERSION}-$.tar.gz"
trap 'rm -f "$TMPFILE"' EXIT
echo "Downloading $ARCHIVE"
if ! download_with_progress "$URL" "$TMPFILE"; then
  echo "Failed to download $URL"
  echo "Releases: https://github.com/${REPO}/releases"
  exit 1
fi

if ! tar -tzf "$TMPFILE" >/dev/null 2>&1; then
  echo "Invalid archive: $ARCHIVE"
  exit 1
fi

# Extract
tar -xzf "$TMPFILE" -C "$INSTALL_DIR"

if [ ! -f "$INSTALL_DIR/gneol" ]; then
  echo "No gneol binary found in $INSTALL_DIR"
  exit 1
fi

# Make the binary executable
chmod +x "$INSTALL_DIR/gneol" 2>/dev/null || true

# Ensure ~/.local/bin is in PATH for current and future sessions
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "Adding ~/.local/bin to PATH"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Clean up
rm -f "$TMPFILE"

echo "gneol installed: $INSTALL_DIR/gneol"
echo "Run 'gneol --help' to get started."
exit 0

