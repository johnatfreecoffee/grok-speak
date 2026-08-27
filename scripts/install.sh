#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"

chmod +x "$ROOT/bin/grok-speak" "$ROOT/scripts/install.sh"

mkdir -p "$GROK_HOME/bin" "$GROK_HOME/skills/speak" "$GROK_HOME/hooks" "$GROK_HOME/commands"

ln -sfn "$ROOT/bin/grok-speak" "$GROK_HOME/bin/grok-speak"

# Real skill dir + file symlink. A directory symlink is skipped by Grok's scanner.
if [[ -L "$GROK_HOME/skills/speak" ]]; then
  rm -f "$GROK_HOME/skills/speak"
  mkdir -p "$GROK_HOME/skills/speak"
fi
ln -sfn "$ROOT/skills/speak/SKILL.md" "$GROK_HOME/skills/speak/SKILL.md"

for cmd in "$ROOT"/commands/*.md; do
  ln -sfn "$cmd" "$GROK_HOME/commands/${cmd:t}"
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
