#!/bin/bash
#
# Pull and regenerate only when it is actually needed.
#
# Editing existing Swift files needs no regeneration — Xcode reads them off disk.
# Adding, deleting or renaming a file does, because XcodeGen writes the file list
# into the project at generation time, and so does any change to project.yml.
# Getting that wrong produces "Cannot find X in scope" for code you can see in
# the sidebar, so this decides it rather than leaving it to memory.
#
# Usage:  ./pull.sh     then press ⌘B in Xcode.

set -e
cd "$(dirname "$0")"

before=$(git rev-parse HEAD)
git pull
after=$(git rev-parse HEAD)

if [ "$before" = "$after" ]; then
    echo ""
    echo "Already up to date — nothing to build."
    exit 0
fi

changed=$(git diff --name-status "$before" "$after")

needs_regen=false
# Any added, deleted or renamed file changes the project's file list.
if echo "$changed" | grep -qE '^[ADR]'; then
    needs_regen=true
fi
# project.yml is the project.
if echo "$changed" | awk '{print $NF}' | grep -qx 'project.yml'; then
    needs_regen=true
fi

echo ""
echo "$changed"
echo ""

if [ "$needs_regen" = false ]; then
    echo "Edits to existing files only — no regeneration needed."
    echo "Press ⌘B in Xcode."
    exit 0
fi

# Find XcodeGen: on PATH, or the unpacked binary SETUP.md uses on macOS 12.
XG=""
if command -v xcodegen >/dev/null 2>&1; then
    XG="xcodegen"
elif [ -x "$HOME/Downloads/xcodegen/bin/xcodegen" ]; then
    XG="$HOME/Downloads/xcodegen/bin/xcodegen"
fi

if [ -z "$XG" ]; then
    echo "The file list changed, so the project needs regenerating — but XcodeGen"
    echo "was not found. See step 3 of SETUP.md, then run:"
    echo ""
    echo "    ~/Downloads/xcodegen/bin/xcodegen generate"
    exit 1
fi

echo "File list or project.yml changed — regenerating."
"$XG" generate

echo ""
echo "Done. Xcode will reload the project on its own; that is expected."
echo "Press ⌘B."
