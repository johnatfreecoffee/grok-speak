# grok-speak

Official Grok voice for the Grok Build TUI. Subscription OAuth (`~/.grok/auth.json`), not an API key.

## Modes
| Mode | What you hear |
|---|---|
| `verbatim` | The reply, markdown stripped |
| `concise` | Short plain-English spoken brief |
| `casual` | Spoken recap, like telling a friend |
| `full` | Whole reply as spoken plain English |

Default: `concise`. Persist in `~/.grok/speak.toml`.

## Commands
- `/speak` — speak last reply in the saved mode. If already talking, stop.
- `/speak stop` — kill playback (and TTS fetch)
- `/speak concise` (or verbatim/casual/full) — speak now in that mode
- `/speak mode casual` — save default, don't speak
- `/speak settings` — print mode + voice
- `⌃⌥S` — Mac Service `Speak Grok Reply`

TUI stop/Esc must kill audio because `afplay` stays in the same process group and grok-speak waits on it.

## Desktop app
`Grok Speak.app` — paste any text and play it locally with skip/seek.
- Default mode **verbatim** (does not change TUI default `concise`)
- Same OAuth + `/v1/tts` via `grok-speak --synthesize`
- AVPlayer: play/pause, ±15s, scrub, speed
- Does not use `afplay` (no seek)

## Settings in the TUI
Grok has no plugin settings pane. `/speak settings` and `/speak mode …` are the TUI controls.
