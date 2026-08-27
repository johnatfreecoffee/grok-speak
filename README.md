# grok-speak

Official Grok voice for Grok Build TUI replies.

```bash
~/Documents/grok-speak/scripts/install.sh
```

Then in any Grok TUI:

| | |
|--|--|
| `/speak` | speak last reply (stops if already talking) |
| `/speak-stop` | cut off |
| `/speak-concise` | one-shot mode (also `-verbatim` `-casual` `-full`) |
| `/speak mode casual` | save default |
| `/speak-settings` | show mode + voice |

Default mode is **concise** (plain-English spoken brief). Prefs: `~/.grok/speak.toml`.

Folder into `~/Documents/grok-speak` from Grok Folders to change it.
