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

## Install

```bash
git clone https://github.com/johnatfreecoffee/grok-speak.git
cd grok-speak
./scripts/install.sh
```

Then **quit and reopen** Grok so `/speak*` shows in the slash menu.

`install.sh` symlinks:

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
```

## Uninstall

Remove the four symlinks under `~/.grok/` and `~/.grok/speak.toml`.
