#!/usr/bin/env bash
# ============================================================
# MY AI SKILLS - One-Click Installer for New Machine (Linux/macOS)
# Copy file này sang máy mới, mở Terminal, chạy:
#   chmod +x install-new-machine.sh && ./install-new-machine.sh
# ============================================================

set -euo pipefail

REPO_URL="https://github.com/KieuTuanKien/my-ai-skills.git"
INSTALL_DIR="$HOME/my-ai-skills"
CURSOR_SKILLS="$HOME/.cursor/skills"
ORCHESTRA_SKILLS="$HOME/.orchestra/skills"

echo ""
echo "===================================================="
echo "  MY AI SKILLS - Full Installer for New Machine"
echo "  105 skills + working rules for Cursor IDE"
echo "===================================================="
echo ""

# --- Step 1: Install Git ---
echo "[1/6] Checking Git..."
if ! command -v git &>/dev/null; then
    echo "  -> Installing Git..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    else
        sudo apt-get update && sudo apt-get install -y git
    fi
    echo "  -> Git installed"
else
    echo "  -> Git OK ($(git --version | sed 's/git version //'))"
fi

# --- Step 2: Install GitHub CLI ---
echo "[2/6] Checking GitHub CLI..."
if ! command -v gh &>/dev/null; then
    echo "  -> Installing GitHub CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gh
    else
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update && sudo apt-get install -y gh
    fi
    echo "  -> GitHub CLI installed"
else
    echo "  -> GitHub CLI OK ($(gh --version | head -1 | sed 's/gh version //'))"
fi

# --- Step 3: Login GitHub ---
echo "[3/6] Checking GitHub login..."
if ! gh auth status &>/dev/null; then
    echo "  -> Please login to GitHub in the browser..."
    gh auth login --web --git-protocol https
    echo "  -> Logged in successfully"
else
    echo "  -> Already logged in"
fi

# --- Step 4: Clone repo ---
echo "[4/6] Cloning skills repo..."
if [ -d "$INSTALL_DIR" ]; then
    echo "  -> Repo exists, pulling latest..."
    cd "$INSTALL_DIR" && git pull && cd -
    echo "  -> Updated to latest"
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo "  -> Cloned to $INSTALL_DIR"
fi

# --- Step 5: Install skills ---
echo "[5/6] Installing skills..."
mkdir -p "$CURSOR_SKILLS" "$ORCHESTRA_SKILLS"

count=0
for skill_dir in "$INSTALL_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    cp -r "$skill_dir" "$CURSOR_SKILLS/$skill_name"

    mkdir -p "$ORCHESTRA_SKILLS/$skill_name"
    [ -f "$skill_dir/SKILL.md" ] && cp "$skill_dir/SKILL.md" "$ORCHESTRA_SKILLS/$skill_name/"
    [ -d "$skill_dir/references" ] && cp -r "$skill_dir/references" "$ORCHESTRA_SKILLS/$skill_name/"

    count=$((count + 1))
done
echo "  -> $count skills installed to ~/.cursor/skills/"
echo "  -> $count skills mirrored to ~/.orchestra/skills/"

# --- Step 6: Install rules ---
echo "[6/6] Installing rules..."
RULES_SRC="$INSTALL_DIR/rules"
RULES_DEST="$(pwd)/.cursor/rules"
mkdir -p "$RULES_DEST"

for rule in "$RULES_SRC"/*.mdc; do
    if [ -f "$rule" ]; then
        cp "$rule" "$RULES_DEST/"
        echo "  -> $(basename "$rule")"
    fi
done
echo "  -> Rules installed to $RULES_DEST"

# --- Done ---
echo ""
echo "===================================================="
echo "  DONE! $count skills + rules installed"
echo ""
echo "  Skills location : $CURSOR_SKILLS"
echo "  Repo location   : $INSTALL_DIR"
echo ""
echo "  Next: Open Cursor IDE and start working!"
echo "===================================================="
echo ""
