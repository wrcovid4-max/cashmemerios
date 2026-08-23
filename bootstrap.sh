#!/bin/bash
#
# One command from a fresh clone to an open Xcode project.
#
# Installs XcodeGen if it is missing, generates CashMemer.xcodeproj, and opens it.
# Deliberately does not need Homebrew: on macOS 12 `brew install xcodegen` fails
# anyway (no bottle, and building it wants Xcode 15.3, which macOS 12 cannot run),
# so this fetches the prebuilt 2.35.0 binary with curl and unzip — both of which
# ship with macOS.
#
# Usage:  ./bootstrap.sh

set -e
cd "$(dirname "$0")"

TOOLS="$HOME/.cashmemer-tools"
XCODEGEN_VERSION="2.35.0"

echo "Cash Memer — setting up"
echo

# ---------------------------------------------------------------- Xcode check
# Everything below needs a working Xcode. A freshly installed Xcode that has
# never been opened fails here rather than three confusing steps later.
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Xcode is not ready yet."
    echo
    echo "  1. Make sure Xcode.app is in /Applications"
    echo "  2. Open it once and accept the licence — the first launch installs"
    echo "     components and takes a few minutes"
    echo "  3. If it is installed but still not found, point the tools at it:"
    echo
    echo "       sudo xcode-select -s /Applications/Xcode.app"
    echo
    echo "Then run this script again."
    exit 1
fi
echo "Xcode:     $(xcodebuild -version | head -1)"

# ---------------------------------------------------------------- XcodeGen
find_xcodegen() {
    if command -v xcodegen >/dev/null 2>&1; then
        command -v xcodegen
    elif [ -x "$TOOLS/xcodegen/bin/xcodegen" ]; then
        echo "$TOOLS/xcodegen/bin/xcodegen"
    elif [ -x "$HOME/Downloads/xcodegen/bin/xcodegen" ]; then
        echo "$HOME/Downloads/xcodegen/bin/xcodegen"
    fi
}

XG=$(find_xcodegen)

if [ -z "$XG" ]; then
    echo "XcodeGen:  not found, downloading $XCODEGEN_VERSION"
    mkdir -p "$TOOLS"
    curl -fsSL -o "$TOOLS/xcodegen.zip" \
        "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
    unzip -oq "$TOOLS/xcodegen.zip" -d "$TOOLS"
    rm -f "$TOOLS/xcodegen.zip"
    XG=$(find_xcodegen)

    if [ -z "$XG" ]; then
        echo "Download finished but the binary is not where expected: $TOOLS/xcodegen/bin"
        exit 1
    fi
fi
echo "XcodeGen:  $XG"

# ---------------------------------------------------------------- Generate
echo
echo "Generating CashMemer.xcodeproj…"
"$XG" generate

echo
echo "Opening Xcode…"
open CashMemer.xcodeproj

cat <<'NEXT'

Done. Two things left, both of which have to be done by hand:

  1. Xcode → Settings → Accounts → + → Apple ID, and sign in.
     Signing fails on all three targets without it.

  2. Wait for the package resolve to finish before building.
     The progress bar at the top of the Xcode window says "Resolving Package
     Graph". The first one takes several minutes — Firebase pulls gRPC, abseil
     and leveldb. Building before it finishes produces errors that look real
     and are not.

Then pick a simulator and press ⌘R.

From here on, to pull changes:  ./pull.sh   then ⌘B in Xcode.
NEXT
