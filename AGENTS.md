# grok-speak

Project: `~/Documents/grok-speak`  
Code: **GS**  
Live binary is this repo. `~/.grok/bin/grok-speak` is a symlink — edit here.

## Do
- Official xAI TTS (`/v1/tts`) + OAuth from `~/.grok/auth.json`
- Non-verbatim modes rewrite via chat completions, then TTS
- `/speak stop` and a second `/speak` must kill `afplay` and the TTS curl
- Wait on `afplay` so TUI Esc/stop kills playback
- User prefs: `~/.grok/speak.toml` (not git)
- Player is **Grok Desk** (per-reply Concise/Casual/Full). This repo is the TTS engine (`--synthesize`). No Swift app.

## Don't
- Don't use macOS `say`
- Don't bill a console API key
- Don't purple the UI (none here)
- Don't detach `afplay` into a new session

Install: `./scripts/install.sh`
