#!/usr/bin/env bash
# Export BuildScene as a Windows .exe (run on macOS/Linux with Godot 4.7 + templates).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PRESET="Windows Desktop"
OUT_DIR="$ROOT/export"
BACKUP="$ROOT/.project.godot.export.bak"

cd "$ROOT"
mkdir -p "$OUT_DIR"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found at: $GODOT" >&2
	echo "Set GODOT= to your Godot 4.7 binary." >&2
	exit 1
fi

# Release build: drop editor-only MCP autoload/plugin so the .exe is standalone.
cp project.godot "$BACKUP"
trap 'mv -f "$BACKUP" project.godot' EXIT

python3 - <<'PY'
import pathlib, re
path = pathlib.Path("project.godot")
text = path.read_text()
text = re.sub(r"\n\[autoload\]\n\n_mcp_game_helper=.*\n", "\n", text)
text = re.sub(
    r'\n\[editor_plugins\]\n\nenabled=PackedStringArray\("res://addons/godot_ai/plugin\.cfg"\)\n',
    "\n",
    text,
)
path.write_text(text)
PY

echo "Exporting $PRESET -> $OUT_DIR/BuildScene.exe ..."
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT_DIR/BuildScene.exe"

echo ""
echo "Done. Windows build:"
ls -lh "$OUT_DIR"/BuildScene.exe "$OUT_DIR"/BuildScene.pck 2>/dev/null || ls -lh "$OUT_DIR"/
