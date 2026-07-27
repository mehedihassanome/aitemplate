# aitemplate

Project-agnostic bootstrap for the **Trellis** workflow framework + **GitNexus** code intelligence (+ skills). Run `setup.sh` in any new project directory to get the full scaffolding in seconds.

## What it sets up

| Component | Per-project | Once-per-machine (`--machine`) |
|-----------|:-----------:|:------------------------------:|
| `.trellis/` (workflow, spec, scripts, tasks, workspace) | ✓ | |
| Platform skill sync — `.claude/`, `.pi/`, `.codex/`, `.agents/` | ✓ | |
| `AGENTS.md`, `CLAUDE.md` | ✓ | |
| `.gitnexus/` knowledge-graph index (`gitnexus analyze`) | ✓ | |
| Global CLIs (`pi`, `trellis`, `gitnexus`) | | ✓ |
| `gitnexus setup` — MCP servers + hooks + gitnexus skills | | ✓ |
| Global skill collections check (`~/.agents/skills/`) | | ✓ |

Global skills in `~/.agents/skills/` and `~/.pi/agent/skills/` are auto-loaded by pi in **every** project — they only need installing once per machine.

## Prerequisites

- **Node.js** (LTS) + npm — only required for `--machine` (installs the CLIs).

## Usage

```bash
# 1. First time on a NEW machine (installs CLIs + configures MCP/hooks/skills),
#    then initializes the current project too:
bash ~/projects/aitemplate/setup.sh --machine

# 2. Any later project — quick per-project init only:
cd ~/projects/some-new-repo
bash ~/projects/aitemplate/setup.sh
```

### Options

```
--machine                 Also run first-time-per-machine setup first
--platforms <a,b,c>       Trellis platforms (default: claude,pi,codex,opencode)
--user <name>             Developer identity (default: git user.name | $USER | developer)
--no-analyze              Skip `gitnexus analyze`
-f, --force               Re-sync platform skills even if .trellis exists
-h, --help                Show help
```

Other valid platforms: `cursor`, `kilo`, `kiro`, `gemini`, `antigravity`, `windsurf`, `qoder`, `codebuddy`, `copilot`, `droid`.

## Idempotent & safe

- Detects an existing `.trellis/` and skips `trellis init` (use `--force` to re-sync).
- Detects an existing `.gitnexus/` and skips re-indexing.
- `gitnexus setup` merges into existing MCP/hook config (safe to re-run).
- `npm install -g` is skipped if the binary is already present.

## Global skills note

`setup.sh --machine` **detects** the global skill collections but does not blindly install them (the installer for non-gitnexus sets varies). If they're missing it prints guidance, e.g.:

```bash
pi install git:github.com/mattpocock/skills   # verify the command for your setup
```

GitNexus's own skills are installed automatically by `gitnexus setup`.

## Files

- `setup.sh` — the bootstrap script.
