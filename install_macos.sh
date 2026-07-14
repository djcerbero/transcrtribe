#!/usr/bin/env bash
# transcrtribe installer for macOS
# Sets up an isolated Python environment and installs the `transcrtribe` CLI
# so it can be run from any Terminal window.
set -euo pipefail

APP_DIR="$HOME/.transcrtribe"
VENV_DIR="$APP_DIR/venv"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/transcrtribe"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m==>\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m==>\033[0m %s\n" "$1"; }

echo ""
echo "  transcrtribe installer"
echo "  ----------------------"
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
  warn "This installer is designed for macOS. Continuing anyway..."
fi

# 1. Homebrew (used for python3 + ffmpeg if missing)
if ! command -v brew >/dev/null 2>&1; then
  info "Homebrew not found. Installing Homebrew (this may prompt for your password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  info "Homebrew found."
fi

# 2. Python — pinned to a version PyTorch actually ships wheels for.
#
# We deliberately do NOT use whatever unversioned `python3` is already on
# PATH: on a machine where Homebrew's `python` formula (or a prior manual
# install) has moved on to a brand-new release, `python3` can point at a
# Python newer than anything torch/ctranslate2 have published wheels for
# yet, which makes `pip install` fail with "No matching distribution found
# for torch" — a real failure users hit, not a config problem on their end.
# python@3.12 is a long-supported version with full wheel coverage across
# the whole ML stack this app depends on, so we pin to it explicitly and
# always use its exact binary for the venv.
PYTHON_FORMULA="python@3.12"
info "Ensuring $PYTHON_FORMULA is installed via Homebrew (this is what transcrtribe's venv will use, independent of your default python3)..."
if ! brew install "$PYTHON_FORMULA"; then
  warn "Retrying after 'brew update' (your local Homebrew formula list may be stale)..."
  brew update
  brew install "$PYTHON_FORMULA"
fi
PY_BIN="$(brew --prefix "$PYTHON_FORMULA")/bin/python3.12"
if [[ ! -x "$PY_BIN" ]]; then
  echo "Could not locate python3.12 after installing $PYTHON_FORMULA via Homebrew." >&2
  exit 1
fi
info "Using Python: $("$PY_BIN" --version) ($PY_BIN)"

# 3. ffmpeg (broadens audio/video format support beyond the bundled decoder)
if ! command -v ffmpeg >/dev/null 2>&1; then
  info "Installing ffmpeg via Homebrew..."
  brew install ffmpeg
else
  info "ffmpeg found."
fi

# 4. Virtual environment
info "Creating isolated environment at $VENV_DIR ..."
mkdir -p "$APP_DIR"
"$PY_BIN" -m venv "$VENV_DIR"

info "Installing transcrtribe and dependencies (this can take a few minutes)..."
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
"$VENV_DIR/bin/pip" install "$REPO_DIR" --quiet

# 5. Launcher on PATH
mkdir -p "$BIN_DIR"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
exec "$VENV_DIR/bin/transcrtribe" "\$@"
EOF
chmod +x "$LAUNCHER"

# 6. Make sure ~/.local/bin is on PATH for common shells
add_path_line() {
  local rc_file="$1"
  local line='export PATH="$HOME/.local/bin:$PATH"'
  if [[ -f "$rc_file" ]] && ! grep -qF "$line" "$rc_file" 2>/dev/null; then
    echo "$line" >> "$rc_file"
  fi
}
add_path_line "$HOME/.zshrc"
add_path_line "$HOME/.bash_profile"

ok "Installation complete!"
echo ""
echo "  Open a NEW terminal window, then run:"
echo ""
echo "      transcrtribe path/to/audio.mp3"
echo ""
echo "  For speaker recognition (who said what), set a free Hugging Face token once:"
echo ""
echo "      export HF_TOKEN=hf_xxxxxxxxxxxx"
echo ""
echo "  Get one at https://huggingface.co/settings/tokens and accept the model terms at"
echo "  https://huggingface.co/pyannote/speaker-diarization-3.1"
echo ""
echo "  Run 'transcrtribe --help' to see all options."
echo ""
