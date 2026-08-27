#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"

chmod +x "$ROOT/bin/grok-speak" "$ROOT/scripts/install.sh"

mkdir -p "$GROK_HOME/bin" "$GROK_HOME/skills" "$GROK_HOME/hooks"

ln -sfn "$ROOT/bin/grok-speak" "$GROK_HOME/bin/grok-speak"

# skill dir: replace a real directory leftover from the first install
if [[ -d "$GROK_HOME/skills/speak" && ! -L "$GROK_HOME/skills/speak" ]]; then
  rm -rf "$GROK_HOME/skills/speak"
fi
ln -sfn "$ROOT/skills/speak" "$GROK_HOME/skills/speak"

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
print "  $GROK_HOME/speak.toml"
