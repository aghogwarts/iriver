#!/bin/bash
# build-ifp-mac.sh — Automated build script for libifp on macOS
# Builds the 'ifp' CLI tool to manage iRiver IFP series players
#
# Usage: chmod +x build-ifp-mac.sh && ./build-ifp-mac.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "═══════════════════════════════════════════════════"
echo "  iRiver IFP Driver Builder for macOS"
echo "  Builds libifp + ifp CLI tool"
echo "═══════════════════════════════════════════════════"
echo ""

# --- Check Homebrew ---
if ! command -v brew &> /dev/null; then
    error "Homebrew not found. Install it first:\n  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi
info "Homebrew found"

# --- Install dependencies ---
echo ""
echo "Installing dependencies..."
brew install libusb libusb-compat wget 2>/dev/null || true
info "Dependencies installed"

LIBUSB_PREFIX=$(brew --prefix libusb-compat)
if [ ! -d "$LIBUSB_PREFIX" ]; then
    error "libusb-compat not found at $LIBUSB_PREFIX"
fi
info "libusb-compat found at $LIBUSB_PREFIX"

# --- Download libifp ---
WORK_DIR="$HOME/ifp-build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

TARBALL="libifp-1.0.1.0.tar.gz"
SRC_DIR="libifp-1.0.1.0"

if [ ! -f "$TARBALL" ]; then
    echo ""
    echo "Downloading libifp 1.0.1.0..."
    wget -q --show-progress \
        "https://sourceforge.net/projects/ifp-driver/files/libifp/1.0.1.0-stable/libifp-1.0.1.0.tar.gz/download" \
        -O "$TARBALL"
    info "Downloaded"
else
    info "Source tarball already present"
fi

if [ -d "$SRC_DIR" ]; then
    rm -rf "$SRC_DIR"
fi
tar xzf "$TARBALL"
cd "$SRC_DIR"
info "Source extracted"

# --- Configure ---
echo ""
echo "Configuring..."
./configure --with-libusb-prefix="$LIBUSB_PREFIX" 2>&1 | tail -5
info "Configured"

# --- Build ---
echo ""
echo "Building..."
if make 2>&1 | tail -10; then
    info "Build succeeded"
else
    warn "Standard make failed, attempting manual link..."
    gcc -g -O2 -o ifp ifp-ifp.o ifp-ifp_routines.o ./libunicodehack.a \
        -liconv \
        "$LIBUSB_PREFIX/lib/libusb.dylib" 2>&1
    if [ -f ifp ]; then
        info "Manual link succeeded"
    else
        error "Build failed. Check errors above."
    fi
fi

# --- Install ---
echo ""
INSTALL_DIR="/usr/local/bin"
if [ -w "$INSTALL_DIR" ]; then
    cp ifp "$INSTALL_DIR/"
    info "Installed to $INSTALL_DIR/ifp"
else
    echo "Installing to $INSTALL_DIR (requires sudo)..."
    sudo cp ifp "$INSTALL_DIR/"
    info "Installed to $INSTALL_DIR/ifp"
fi

# --- Verify ---
echo ""
echo "═══════════════════════════════════════════════════"
echo ""
if command -v ifp &> /dev/null; then
    info "Installation complete!"
    echo ""
    echo "  Plug in your iRiver IFP player and try:"
    echo ""
    echo "    ifp ls /          # list files"
    echo "    ifp battery       # battery status"
    echo "    ifp df            # free space"
    echo "    ifp typestring    # model info"
    echo ""
    echo "  Upload music:"
    echo "    ifp upload ~/Music/song.mp3 /"
    echo ""
    echo "  If you get 'permission denied', prefix with sudo:"
    echo "    sudo ifp ls /"
    echo ""
else
    warn "ifp binary built but not in PATH"
    echo "  Binary location: $WORK_DIR/$SRC_DIR/ifp"
    echo "  Try: $WORK_DIR/$SRC_DIR/ifp ls /"
fi

echo "═══════════════════════════════════════════════════"
echo ""
