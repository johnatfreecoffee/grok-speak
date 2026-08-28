# grok-speak

Official **Grok voice** for [Grok Build](https://x.ai/build) TUI replies.

Not macOS `say`. Real xAI TTS (`POST /v1/tts`) using your **Grok login** — same OAuth session as the TUI. No console API key.

Built with Grok Build.

| | |
|--|--|
| **Repo** | https://github.com/johnatfreecoffee/grok-speak |
| **License** | [MIT](LICENSE) |
| **Requires** | macOS + [Grok CLI](https://x.ai/build) logged in (`grok login`) |

## What you get

After a turn finishes, speak it:

| Command | |
|--|--|
| `/speak` | speak last reply (stops if already talking) |
| `/speak-stop` | cut off |
| `/speak-concise` | short plain-English brief |
| `/speak-casual` | like telling a friend |
| `/speak-verbatim` | read the reply |
| `/speak-full` | whole reply as spoken English |
| `/speak-settings` | show mode + voice |

Default mode is **concise**. Prefs: `~/.grok/speak.toml`. Voice default: **rex**.

Esc / TUI Stop kills playback — `afplay` stays in-process.

## Desktop app

**Grok Speak.app** — paste any text and hear it with the same Grok voice.

TUI `/speak` defaults to concise recap. The app defaults to **verbatim**: it reads what you pasted. Play, pause, skip ±15s, scrub, and speed are local (AVPlayer, not `afplay`).

Install puts it in `~/Applications/Grok Speak.app`.

```
⌘↩ Speak
⌘. Stop
⌘⌥← / ⌘⌥→ skip 15s
⌘L load last Grok reply
```

`grok-speak --synthesize --out file.mp3` writes audio without playing — that’s what the app uses.

## Install

```bash
git clone https://github.com/johnatfreecoffee/grok-speak.git
cd grok-speak
./scripts/install.sh
```

Then **quit and reopen** Grok so `/speak*` shows in the slash menu.

`install.sh` also builds **Grok Speak.app** into `~/Applications`.

It symlinks:

- `~/.grok/bin/grok-speak`
- `~/.grok/skills/speak/SKILL.md`
- `~/.grok/commands/speak*.md`
- `~/.grok/hooks/speak-cache.json`

## How it works

1. A Grok **Stop hook** caches `lastAssistantMessage` to `~/.grok/last-reply.txt`
2. `/speak` (or `grok-speak`) reads that
3. Non-verbatim modes rewrite via chat completions into something you’d actually say
4. TTS with the Grok login token
5. `afplay` — wait, same process group, so stop works

```bash
grok-speak              # saved mode
grok-speak --stop
grok-speak concise
grok-speak mode casual  # save default, don’t speak
grok-speak --settings
grok-speak --synthesize verbatim --stdin --out ~/Desktop/out.mp3
```

## Uninstall

Remove the four symlinks under `~/.grok/`, `~/.grok/speak.toml`, and `~/Applications/Grok Speak.app`.
