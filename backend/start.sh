#!/bin/zsh
# Starts the Screen Scout server. The first run sets everything up.
#   Usage:  ./start.sh   (from the backend folder)
set -e
cd "$(dirname "$0")"

PY=$(command -v python3.12 || command -v python3)
if [ ! -d .venv ]; then
  echo "First run: setting up Python (takes a minute)..."
  "$PY" -m venv .venv
fi
source .venv/bin/activate
pip install -q --disable-pip-version-check -r requirements.txt

# Keep saved reviews and accounts outside the project folder so they survive
# updates and fresh clones.
DATA_DIR="$HOME/ScreenScout-data"
mkdir -p "$DATA_DIR"
export SCOUT_DB="$DATA_DIR/reviews.db"
OLD_DB="$HOME/Downloads/screen-scout/backend/data/reviews.db"
if [ ! -f "$SCOUT_DB" ] && [ -f "$OLD_DB" ]; then
  cp "$OLD_DB" "$SCOUT_DB"
  echo "Brought over your saved reviews and accounts."
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "ANTHROPIC_API_KEY isn't set. Add it to ~/.zshrc, then open a new Terminal window."
  exit 1
fi

echo "Screen Scout server starting at http://$(ipconfig getifaddr en0 2>/dev/null || echo localhost):8000"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
