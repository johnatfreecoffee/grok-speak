#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"

chmod +x "$ROOT/bin/grok-speak" "$ROOT/scripts/install.sh"

mkdir -p "$GROK_HOME/bin" "$GROK_HOME/skills/speak" "$GROK_HOME/hooks" "$GROK_HOME/commands"

ln -sfn "$ROOT/bin/grok-speak" "$GROK_HOME/bin/grok-speak"

# Copy skill/commands (not symlink). Grok watches ~/.grok and misses target-only edits.
if [[ -L "$GROK_HOME/skills/speak" ]]; then
  rm -f "$GROK_HOME/skills/speak"
  mkdir -p "$GROK_HOME/skills/speak"
fi
rm -f "$GROK_HOME/skills/speak/SKILL.md"
cp -f "$ROOT/skills/speak/SKILL.md" "$GROK_HOME/skills/speak/SKILL.md"

for cmd in "$ROOT"/commands/*.md; do
  rm -f "$GROK_HOME/commands/${cmd:t}"
  cp -f "$cmd" "$GROK_HOME/commands/${cmd:t}"
done

if [[ -f "$GROK_HOME/hooks/speak-cache.json" && ! -L "$GROK_HOME/hooks/speak-cache.json" ]]; then
  rm -f "$GROK_HOME/hooks/speak-cache.json"
fi
ln -sfn "$ROOT/hooks/speak-cache.json" "$GROK_HOME/hooks/speak-cache.json"

if [[ ! -f "$GROK_HOME/speak.toml" ]]; then
  sed '1,3d' "$ROOT/speak.toml.example" > "$GROK_HOME/speak.toml"
fi

print "installed:"
print "  $GROK_HOME/bin/grok-speak -> $ROOT/bin/grok-speak"
print "  $GROK_HOME/skills/speak"
print "  $GROK_HOME/hooks/speak-cache.json"
print "  $GROK_HOME/commands/speak*.md"
print "  $GROK_HOME/speak.toml"

print ""
print "Building Grok Speak.app…"
APP="$("$ROOT/scripts/build-app.sh")"
DEST="$HOME/Applications/Grok Speak.app"
pkill -f '/Grok Speak.app/Contents/MacOS/GrokSpeak' 2>/dev/null || true
sleep 0.2
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force --deep --sign - "$DEST" >/dev/null
open "$DEST"
print "  $DEST"
