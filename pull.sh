#!/bin/bash
#
# Pull and regenerate the Xcode project when it needs it.
#
# Editing existing Swift files needs no regeneration — Xcode reads them off disk.
# Adding, deleting or renaming a file does, because XcodeGen writes the file list
# into the project at generation time, and so does any change to project.yml.
# Getting that wrong produces "Cannot find X in scope" for code you can see in
# the sidebar, so this decides it rather than leaving it to memory.
#
# It checks two things: whether the commits just pulled changed the file set, and
# — regardless of that — whether the project on disk is actually missing any
# tracked Swift file. The second check matters because a plain `git pull` run by
# hand leaves nothing for the first one to find.
#
# Usage:  ./pull.sh     then press ⌘B in Xcode.

set -e
cd "$(dirname "$0")"

PROJECT="CashMemer.xcodeproj/project.pbxproj"

before=$(git rev-parse HEAD)
git pull
after=$(git rev-parse HEAD)

needs_regen=false
reason=""

if [ "$before" != "$after" ]; then
    changed=$(git diff --name-status "$before" "$after")
    echo ""
    echo "$changed"
    echo ""

    # Any added, deleted or renamed file changes the project's file list.
    if echo "$changed" | grep -qE '^[ADR]'; then
        needs_regen=true
        reason="the file list changed"
    fi
    # project.yml is the project.
    if echo "$changed" | awk '{print $NF}' | grep -qx 'project.yml'; then
        needs_regen=true
        reason="project.yml changed"
    fi
else
    echo ""
    echo "Already up to date."
fi

# Belt and braces: is the generated project actually missing anything? This
# catches a project left stale by an earlier hand-run `git pull`, which is
# exactly the case the diff check above cannot see.
if [ "$needs_regen" = false ]; then
    if [ ! -f "$PROJECT" ]; then
        needs_regen=true
        reason="no generated project yet"
    else
        missing=""
        while IFS= read -r file; do
            base=$(basename "$file")
            grep -q "$base" "$PROJECT" || missing="$missing $base"
        done < <(git ls-files '*.swift')

        if [ -n "$missing" ]; then
            needs_regen=true
            reason="files on disk but not in the project:$missing"
        fi
    fi
fi

if [ "$needs_regen" = false ]; then
    echo "Project is up to date — no regeneration needed."
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
    echo "Needs regenerating ($reason) — but XcodeGen was not found."
    echo "See step 3 of SETUP.md, then run:"
    echo ""
    echo "    ~/Downloads/xcodegen/bin/xcodegen generate"
    exit 1
fi

echo "Regenerating — $reason."
"$XG" generate

echo ""
echo "Done. Xcode will reload the project on its own; that is expected."
echo "Press ⌘B."
