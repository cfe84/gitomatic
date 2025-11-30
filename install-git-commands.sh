#!/bin/bash

# Installation script for git-build client tools
# Copies client scripts to $HOME/bin

set -e

INSTALL_DIR="$HOME/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

echo "Installing git-build client tools..."
echo ""

# Create $HOME/bin if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Creating directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# Copy all git-* scripts from bin/ to $HOME/bin
echo "Copying scripts to $INSTALL_DIR..."
for script in "$BIN_DIR"/git-*; do
  if [ -f "$script" ]; then
    SCRIPT_NAME=$(basename "$script")
    echo "  - $SCRIPT_NAME"
    cp "$script" "$INSTALL_DIR/$SCRIPT_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
  fi
done

echo ""
echo "✅ Installation complete!"
echo ""

# Check if $HOME/bin is in PATH
if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
  echo "✅ $INSTALL_DIR is already in your PATH"
else
  echo "⚠️  $INSTALL_DIR is not in your PATH"
  echo ""
  echo "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "    export PATH=\"\$HOME/bin:\$PATH\""
  echo ""
  echo "Then reload your shell or run: source ~/.zshrc"
fi

echo ""
echo "Usage:"
echo "  git-build logs last           # Show last log"
echo "  git-build logs all            # Show all logs"
echo "  git-build logs ls             # List log files with dates"
echo "  git-build logs show <file>    # Show specific log file"
echo ""
echo "Options:"
echo "  --repo|-r <path>              # Specify repository (default: current)"
echo ""
