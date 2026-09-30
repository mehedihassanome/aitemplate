# aitemplate

> One-command bootstrap for an AI-agent-ready project, in one of two directions: **code** or **noncode**.

[License: MIT](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform: macOS / Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)](#prerequisites)

A repo is either **code** (it has source to navigate) or **noncode** (it is documents,
research, or design). Those need *different* tooling. This template wires the right subset
for each, so a docs repo never gets a 0-file code index and a service repo never gets a
collaborative-document layer it did not ask for.

## The two directions

|                    | `--code`                        | `--noncode`                     |
| ------------------ | ------------------------------- | ------------------------------- |
| **For**            | services, libraries, CLIs, apps | docs, research, design, writing |
| **Process**        | Trellis → `.trellis/`           | Trellis → `.trellis/`           |
| **Knowledge**      | iwe → `.iwe/`                   | iwe → `.iwe/`                   |
| **Third layer**    | **GitNexus** → `.gitnexus/`     | **OpenKnowledge** → `.ok/`      |
| **MCP servers**    | `gitnexus`, `iwe`               | `iwe`, `open-knowledge`         |
| **Skills checked** | 7 × `gitnexus-*`                | `open-knowledge-*`              |
| **Seeded**         | —                               | starter doc pack (`ok seed`)    |

``` bash
setup.sh --code        # or: --noncode
setup.sh --code -n     # dry run: print everything, change nothing
```

No flag? It detects — source files present means `code`, otherwise `noncode` — and asks
you to confirm at a terminal, or proceeds silently when stdin is not a terminal.

**Read next:** [docs/code.md](docs/code) · [docs/noncode.md](docs/noncode)

## Why the split

The two third-layers are not alternatives at the same job.

- **GitNexus** builds a graph of symbols: functions, classes, imports, execution flows.
  On a docs repo it produces a 0-file index that looks like success and answers nothing.
- **OpenKnowledge** is a CRDT document store: history, checkpoints, conflict resolution.
  On a service repo it duplicates what git already does for code, and adds a server to
  keep running.

Trellis and iwe are shared because both are useful in either direction — a docs repo still
has a task lifecycle, and both need a knowledge graph.

A project can start noncode and grow code. Run `--code` later: it adds GitNexus and
leaves `.iwe/` and `.ok/` untouched. Nothing is overwritten.

## What each layer is for

| Layer         | System            | Question it answers                                     |
| ------------- | ----------------- | ------------------------------------------------------- |
| Process       | **Trellis**       | "What task am I on, and what phase?"                    |
| Knowledge     | **iwe**           | "What was decided, and what connects to it?"            |
| Code          | **GitNexus**      | "What calls this, and what breaks if I change it?"      |
| Collaboration | **OpenKnowledge** | "Who changed this, and can I get the old version back?" |

Two tools claiming one layer is how drift starts. This template keeps the split strict,
and each guide states the rules that follow from it.

## Prerequisites

Always:

- **macOS or Linux** with **Bash 4+**. Windows: use WSL2.
- **git** — Trellis uses worktrees, task branches, and commit metadata.
- **Python 3.9+** — Trellis renders this into hook scripts and warns below 3.9.

Per direction:

| Direction   | Needs         | Install                                               |
| ----------- | ------------- | ----------------------------------------------------- |
| both        | Trellis       | `npm i -g @mindfoldhq/trellis`                        |
| both        | iwe           | `cargo install iwe`                                   |
| `--code`    | GitNexus      | `npm i -g gitnexus`                                   |
| `--noncode` | OpenKnowledge | `npm i -g @inkeep/open-knowledge`, or the desktop app |

`--machine` installs all of them and skips whatever is present.

## Usage

``` bash
# once per machine
setup.sh --machine --code

# per project
cd ~/projects/some-repo
setup.sh --noncode
```

### Options

```
--code                   Code project:     Trellis + GitNexus + iwe
--noncode                Noncode project:  Trellis + iwe + OpenKnowledge
--auto                   Detect the direction; never prompt
--machine                Also run first-time-per-machine setup first
--platforms <a,b,c>      Trellis platforms (default: claude,pi,codex,opencode)
--user <name>            Developer identity (default: git user.name | $USER | developer)
--no-analyze             Skip `gitnexus analyze`          (--code)
--no-seed                Skip `ok seed`                   (--noncode)
--seed-pack <id>         Starter pack (default: plain-notes)
-f, --force              Re-sync Trellis platform skills
-n, --dry-run            Print what would run, change nothing
-h, --help               Full help
```

## Idempotent

Safe to re-run. Each step detects what exists and skips it:

```
✓ .trellis already initialized (use --force to re-sync platform skills)
✓ .mcp.json already present (left untouched)
✓ .gitnexus index already present (run `gitnexus analyze` manually to refresh)
```

It never overwrites an existing `.mcp.json` or `.iwe/config.toml` — those are yours once
written. It appends to `.gitignore` only if the entry is absent.

## What lands where

**Committed** (your team inherits the workflow):

```
.trellis/            workflow, specs, tasks
.iwe/                knowledge graph config
.mcp.json            MCP server registration
.agents/ .claude/ .pi/ .codex/ .opencode/    per-agent config
AGENTS.md  CLAUDE.md
.ok/                 (--noncode) OpenKnowledge config
```

**Gitignored** (machine-regenerated or personal):

```
.gitnexus/           code index — rebuild with `gitnexus analyze`
.trellis/workspace/  personal session journals
.ok/cache/           OpenKnowledge cache
```

## MCP servers

`.mcp.json` is the Claude Code and Cursor convention. **Codex and OpenCode do not read
it** — they need their own config entries. Both guides have the exact blocks:

- [docs/code.md](docs/code#agents-that-do-not-read-mcpjson)
- [docs/noncode.md](docs/noncode#agents-that-do-not-read-mcpjson)

`setup.sh` writes `.mcp.json` and does not edit your global configs. `gitnexus setup` and
`ok init` do register their own servers — that is their job, and they merge rather than
overwrite.

## Skills

The 25 skills in `~/.agents/skills/` are machine-wide and auto-load in every project.
There is no per-project install step. `setup.sh` checks that the direction's skills are
present and names any that are missing.

Full inventory: [docs/skills.md](docs/skills).

## Troubleshooting

| Symptom                            | Cause                       | Fix                                                                               |
| ---------------------------------- | --------------------------- | --------------------------------------------------------------------------------- |
| `trellis CLI missing`              | not installed               | `setup.sh --machine`, or `npm i -g @mindfoldhq/trellis`                           |
| `iwe CLI missing`                  | cargo not on PATH           | `cargo install iwe`; the script writes a fallback config so setup still completes |
| MCP tools absent in Codex/OpenCode | they don't read `.mcp.json` | see the per-direction guide                                                       |
| `iwe: command not found` as an MCP | config points at `iwe`      | the MCP binary is `iwec`; the CLI is `iwe`                                        |
| GitNexus finds 0 files             | wrong direction             | re-run with `--noncode`                                                           |
| OpenKnowledge writes fail          | no server running           | `ok start`; `ok lint` and `iwe schema validate` work without it                   |
| `ok seed` hangs                    | it prompts for confirmation | the script passes `--yes`; run it manually with `--yes` too                       |
| `iwe find` returns nothing         | library empty               | iwe scans once at `init` and never rescans — it must run *after* content exists   |

## License

MIT — see [LICENSE](LICENSE).
