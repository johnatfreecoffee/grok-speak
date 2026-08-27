---
description: Speak the last Grok reply (official Grok voice). Args: stop, settings, verbatim, concise, casual, full, mode <name>
argument-hint: "[stop|settings|verbatim|concise|casual|full]"
---

Run exactly one shell command, nothing else. Do not use macOS `say`. Timeout 300s.

If `$ARGUMENTS` is empty: `~/.grok/bin/grok-speak`
If `$ARGUMENTS` is `stop`: `~/.grok/bin/grok-speak --stop`
Otherwise: `~/.grok/bin/grok-speak $ARGUMENTS`
