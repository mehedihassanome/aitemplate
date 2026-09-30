# `--noncode` direction

For a docs repo, research archive, design collection, writing project, or knowledge base.
There is no source to index, so **OpenKnowledge** replaces GitNexus as the collaboration
and editing layer.

## What gets installed

| Layer     | Tool                | Lands in                     | Why                                                                    |
| --------- | ------------------- | ---------------------------- | ---------------------------------------------------------------------- |
| Process   | Trellis             | `.trellis/` + per-agent dirs | keeps a research/writing project structured too                        |
| Knowledge | iwe                 | `.iwe/`, `.mcp.json`         | markdown knowledge graph — the doc corpus itself                       |
| Collab    | OpenKnowledge       | `.ok/`                       | CRDT editing, history, checkpoints, conflict resolution, audit         |
| Skills    | `~/.agents/skills/` | machine-wide                 | `open-knowledge-discovery`, `open-knowledge-write-skill`, + global set |

MCP servers registered in `.mcp.json`: **iwe**, **open-knowledge**.

## Why no GitNexus

GitNexus builds a graph of symbols — functions, classes, imports, execution flows. A
noncode repo has none of those. Running `gitnexus analyze` on it produces a 0-file index
that looks like success and answers nothing. The knowledge you actually want to navigate —
documents, their cross-links, their history — is what iwe and OpenKnowledge do.

If a noncode project later grows real source code (a build script, a generator, an
analysis tool), the honest fix is a **second** direction, not a swap:

``` bash
setup.sh --code     # adds GitNexus alongside, keeps .iwe/ and .ok/ intact
```

Both directions share Trellis and iwe, so this composes. Nothing is overwritten.

## iwe vs OpenKnowledge — they are not redundant

Both touch markdown. They do different jobs.

|                    | iwe                                                                                | OpenKnowledge                                                                           |
| ------------------ | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Model**          | knowledge graph (documents as nodes, links as edges)                               | collaborative document store (CRDT)                                                     |
| **Reads for**      | "what do we know about X, and what connects to it"                                 | "who changed this, and can I get the old version back"                                  |
| **Strong feature** | `retrieve --expand`, `extract`, `inline`, `squash`, `tree` — structural navigation | `checkpoint`, `history`, `restore_version`, `conflicts`, `audit` — collaborative safety |
| **Needs a server** | No — pure CLI                                                                      | Yes, for writes. Lint and search are headless                                           |
| **Fails when**     | library is unnormalized; links drift                                               | no `ok start` running, and you try `write`                                              |

Use both. iwe for structure, OpenKnowledge for not losing work.

## Rules this direction implies

1. **`ok start` before any collaborative write.** `write`, `edit`, `checkpoint`,
   `history`, `restore_version`, and `resolve_conflict` all require a running
   Hocuspocus server. Without it they fail — this is not a config error.
2. **Headless checks do not need it.** `ok lint` and `iwe schema validate` run fine with
   no server. In CI, use those.
3. **Edit documents, do not replace them.** A `write` is refused when another writer
   touched the doc in the last seconds. Use `edit` (find + replace) instead, or wait and
   retry.
4. **On `content-divergence`, re-read before retrying.** The disk copy moved under the
   CRDT. `exec("cat <path>")` to see what is actually there, then reconcile.
5. **Run `iwe normalize` after bulk edits** — and scope it with `-k`. An unscoped
   `iwe normalize` rewrites *every* document in the library.
6. **Structure decisions into documents.** This direction has no code to carry them, so a
   decision that lives only in a chat log is lost.

## Re-running

``` bash
setup.sh --noncode                # skips what exists
setup.sh --noncode --no-seed      # scaffolding without the starter knowledge base
setup.sh --noncode -f             # re-sync Trellis platform skills
```

## Troubleshooting

| Symptom                                         | Cause                                                      | Fix                                                             |
| ----------------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------- |
| `write` returns a server-not-running error      | no `ok start`                                              | `ok start` in another terminal                                  |
| `.ok/` missing                                  | `ok` CLI not installed                                     | `setup.sh --machine --noncode`, or the desktop app              |
| `audit` fails to connect                        | `audit` needs the server; `lint` does not                  | use `ok lint` when headless                                     |
| `iwe find` returns nothing                      | library not initialized, or paths outside the library root | `iwe init --auto`; check `[library] path` in `.iwe/config.toml` |
| `iwe normalize` rewrote files you did not touch | unscoped normalize                                         | expected; use `-k <key>` to scope, and `git diff` to review     |

### Agents that do not read `.mcp.json`

**Codex** — `~/.codex/config.toml`:

``` toml
[mcp_servers.iwe]
command = "iwec"
args = []

[mcp_servers.open-knowledge]
command = "ok"
args = ["mcp"]
```

**OpenCode** — the OpenKnowledge MCP server is normally already registered at user level
by `ok init`. Confirm with `opencode mcp list` before adding a project-level duplicate.
A duplicate entry shadows the user-level one and loses the desktop app's bundle path.
