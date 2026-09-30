# `--code` direction

For a service, library, CLI, or app. A code project has a **code graph** to query, so
GitNexus is the code layer and iwe is the knowledge layer.

## What gets installed

| Layer     | Tool                | Lands in                                                  | Why                                               |
| --------- | ------------------- | --------------------------------------------------------- | ------------------------------------------------- |
| Process   | Trellis             | `.trellis/` + `.claude/ .pi/ .codex/ .opencode/ .agents/` | task lifecycle, specs, session journals           |
| Knowledge | iwe                 | `.iwe/`, `.mcp.json`                                      | markdown knowledge graph — specs, decisions, docs |
| Code      | GitNexus            | `.gitnexus/` (gitignored)                                 | calls, imports, execution flows, blast radius     |
| Skills    | `~/.agents/skills/` | machine-wide                                              | 7 GitNexus guides + the global collection         |

MCP servers registered in `.mcp.json`: **gitnexus**, **iwe**.

## The two graphs, and why both

GitNexus and iwe answer different questions about the same repo. Neither replaces the
other.

```
a question ──┬── "what calls this function?"      → gitnexus query / context
             ├── "what breaks if I rename it?"    → gitnexus impact
             ├── "why does this test fail?"       → gitnexus debugging skill
             ├── "why is it designed this way?"   → iwe retrieve
             └── "what did we decide last time?"  → iwe retrieve
```

iwe indexes the **markdown**; GitNexus indexes the **source**. A design doc in `docs/`
is in iwe and invisible to GitNexus. A function is in GitNexus and invisible to iwe.

## Rules this direction implies

1. **Run `gitnexus_impact` before editing any symbol.** Report the blast radius to the
   user. Warn on HIGH or CRITICAL before proceeding.
2. **Run `gitnexus_detect_changes` before committing.** Confirm only expected symbols
   and flows moved.
3. **Never rename with find-and-replace.** Use `gitnexus_rename` — it understands the
   call graph. A text replace silently breaks callers.
4. **Refresh the index when it goes stale.** If any GitNexus tool warns, run
   `gitnexus analyze`. A stale index makes impact analysis *lie confidently*, which is
   worse than no index.
5. **Decisions go in iwe, not in code comments.** If a decision is worth keeping, it is a
   document, and documents are iwe's layer.

## Re-running

``` bash
setup.sh --code                    # skips what exists
setup.sh --code --no-analyze       # rebuild scaffolding, keep the existing index
setup.sh --code -f                 # re-sync Trellis platform skills
```

## After `git commit`

If you commit source changes, refresh the index — otherwise the next agent reasons about
yesterday's code:

``` bash
gitnexus analyze
```

## Troubleshooting

| Symptom                                 | Cause                           | Fix                                                      |
| --------------------------------------- | ------------------------------- | -------------------------------------------------------- |
| `gitnexus: command not found`           | CLI missing                     | `setup.sh --machine --code`, or `npm i -g gitnexus`      |
| MCP tools absent in an agent            | Agent does not read `.mcp.json` | Codex and OpenCode need their own config key — see below |
| Impact returns empty for a known symbol | Index is stale                  | `gitnexus analyze`                                       |
| Index is 0 files                        | Only markdown in the repo       | This is the wrong direction — use `--noncode`            |

### Agents that do not read `.mcp.json`

`.mcp.json` is the Claude Code and Cursor convention. Other agents need their own entry.

**Codex** — `~/.codex/config.toml`:

``` toml
[mcp_servers.gitnexus]
command = "gitnexus"
args = ["mcp"]

[mcp_servers.iwe]
command = "iwec"
args = []
```

**OpenCode** — `opencode.json` in the project root:

``` json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "gitnexus": { "type": "local", "enabled": true, "command": ["gitnexus", "mcp"] },
    "iwe": {
      "type": "local",
      "enabled": true,
      "cwd": ".",
      "command": ["/bin/sh", "-l", "-c", "command -v iwec >/dev/null 2>&1 && exec iwec\n[ -x \"$HOME/.cargo/bin/iwec\" ] && exec \"$HOME/.cargo/bin/iwec\"\nexit 127"]
    }
  }
}
```

The OpenCode `iwe` entry guards `iwec` twice on purpose. Cargo's `~/.cargo/bin` is not
always on `PATH` in a login shell, and a bare `command: "iwec"` fails there. `setup.sh`
writes only `.mcp.json`; it does not edit a global config for you.

### iwe CLI is not iwe MCP

`iwe` is the CLI. `iwec` is the MCP server. They are different binaries from the same
install. A config pointing at `iwe` as the MCP command is a common mistake and produces a
server that starts and then answers nothing.
