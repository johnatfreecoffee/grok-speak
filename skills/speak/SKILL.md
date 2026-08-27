---
name: speak
description: Speak the last Grok TUI reply with official Grok TTS. Use when the user runs /speak, wants the last response read aloud, or says speak that. Modes: verbatim, concise, casual, full. Pass stop to cut off playback. Pass settings or mode <name> to change defaults.
user-invocable: true
disable-model-invocation: false
argument-hint: "[stop|settings|mode|verbatim|concise|casual|full]"
allowed-tools: run_terminal_command
---

# Speak last reply

Run **one** `~/.grok/bin/grok-speak` command. Do not rewrite the reply yourself. Do not use macOS `say`.

Use a long timeout (at least 300 seconds) so TTS can finish.

| User said | Command |
|---|---|
| `/speak stop` or stop / shut up / cut it off | `~/.grok/bin/grok-speak --stop` |
| `/speak` while it is already talking | `~/.grok/bin/grok-speak --stop` |
| `/speak settings` | `~/.grok/bin/grok-speak --settings` |
| `/speak mode concise` (or verbatim/casual/full) | `~/.grok/bin/grok-speak mode concise` |
| `/speak concise` (or verbatim/casual/full) | `~/.grok/bin/grok-speak concise` |
| `/speak` | `~/.grok/bin/grok-speak` |

`--stop` must actually kill `afplay`. If the first stop fails, run it again. Do not start a new speak after a stop unless they asked to speak in a named mode.

Then stop. No extra commentary unless the command failed.
