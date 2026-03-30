# PPPoker

MacroQuest **Lua** automation for the EverQuest **Paintings Playing Poker** (23rd anniversary) quest line.

## Contents

- **`init.lua`** — main PPPoker runner (ImGui, objectives, travel).
- **`init_pppoker_v1_27.lua`** — backup of legacy v1.27 pipeline script; not loaded by default.
- **`Poker2.lua`**, **`Poker.lua`**, etc. — related helpers / timing.
- **`mq_task_diag.lua`** — optional diagnostics.

Quest reference: [Allakhazam — Paintings Playing Poker](https://everquest.allakhazam.com/db/quest.html?quest=10723).

## Requirements

- [MacroQuest](https://www.macroquest.com/) (Live), Lua plugin, typical MQ2 plugins as referenced by the scripts (e.g. Nav, ImGui).

## Run

Use your usual MQ Lua load path (e.g. `/lua run .../pppoker/init` per your MacroQuest setup). Primary entry: **`init.lua`**.

## Publish to GitHub (first time)

1. Install **Git** and **GitHub CLI** (`gh`) if needed (e.g. `winget install Git.Git` and `winget install GitHub.cli`).
2. Log in: open **PowerShell** and run `"C:\Program Files\GitHub CLI\gh.exe" auth login` (browser or token flow).
3. From this folder:

```powershell
cd $env:USERPROFILE\Desktop\Scripts\pppoker
& "C:\Program Files\GitHub CLI\gh.exe" repo create pppoker --public --source=. --remote=origin --push
```

That creates a **public** repo named `pppoker` on your account and pushes `main`.

If the repo name is taken, use e.g. `repo create pppoker-mq --public ...`. To set your real name/email for commits: `git config user.name "..."` and `git config user.email "..."` in this directory.

## License / credits

By RedFrog / community scripts; use at your own risk in-game.
