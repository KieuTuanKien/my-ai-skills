#!/usr/bin/env bash
# ============================================================
# MY AI SKILLS - Setup Script (Linux/macOS)
# One command to install all skills & rules on a new machine
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_SRC="$REPO_ROOT/skills"
RULES_SRC="$REPO_ROOT/rules"

CURSOR_SKILLS="$HOME/.cursor/skills"
ORCHESTRA_SKILLS="$HOME/.orchestra/skills"

PROJECT_PATH="${1:-$(pwd)}"
SKIP_ORCHESTRA="${SKIP_ORCHESTRA:-false}"
SKIP_RULES="${SKIP_RULES:-false}"

echo "========================================"
echo "  MY AI SKILLS - Setup Installer"
echo "========================================"
echo ""

# --- Install Skills to ~/.cursor/skills/ ---
echo "[1/3] Installing skills to $CURSOR_SKILLS ..."
mkdir -p "$CURSOR_SKILLS"
count=0
for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    cp -r "$skill_dir" "$CURSOR_SKILLS/$skill_name"
    count=$((count + 1))
done
echo "  -> $count skills installed"

# --- Install Skills to ~/.orchestra/skills/ ---
if [ "$SKIP_ORCHESTRA" != "true" ]; then
    echo "[2/3] Installing skills to $ORCHESTRA_SKILLS ..."
    mkdir -p "$ORCHESTRA_SKILLS"
    for skill_dir in "$SKILLS_SRC"/*/; do
        skill_name=$(basename "$skill_dir")
        dest="$ORCHESTRA_SKILLS/$skill_name"
        mkdir -p "$dest"
        [ -f "$skill_dir/SKILL.md" ] && cp "$skill_dir/SKILL.md" "$dest/"
        [ -d "$skill_dir/references" ] && cp -r "$skill_dir/references" "$dest/"
    done
    echo "  -> $count skills mirrored to Orchestra"
else
    echo "[2/3] Skipping Orchestra installation"
fi

# --- Install Rules ---
if [ "$SKIP_RULES" != "true" ]; then
    RULES_DEST="$PROJECT_PATH/.cursor/rules"
    echo "[3/3] Installing rules to $RULES_DEST ..."
    mkdir -p "$RULES_DEST"
    for rule in "$RULES_SRC"/*.mdc; do
        [ -f "$rule" ] && cp "$rule" "$RULES_DEST/"
        echo "  -> $(basename "$rule")"
    done
else
    echo "[3/3] Skipping rules installation"
fi

echo ""
echo "========================================"
echo "  Setup complete!"
echo "  $count skills + rules installed"
echo "========================================"
