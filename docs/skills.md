# Global skills — `~/.agents/skills/`

Machine-wide, installed once, **auto-loaded in every project**. No per-project install
step exists or is needed; `setup.sh` only checks that these are present.

Vendor-neutral location. `~/.claude/skills/`, `~/.codex/skills/`, `~/.opencode/skills/`,
`~/.pi/agent/skills/`, and `~/.copilot/skills/` are *projections* of it — several agents
read only their own directory, so `ok init` and `gitnexus setup` fan copies out from here.
A skill in `~/.agents/skills/` reaches all of them. A skill in only one agent's directory
reaches only that agent.

## Inventory (25 skills)

| Skill                          | Files | Group     | Fires when                                                                                                                 |
| ------------------------------ | ----- | --------- | -------------------------------------------------------------------------------------------------------------------------- |
| `open-knowledge-discovery`     | 1     | knowledge | Asking what OpenKnowledge is, installing it, opening a single file                                                         |
| `open-knowledge-write-skill`   | 3     | knowledge | Authoring or designing a `SKILL.md`; carries a `references/` bundle                                                        |
| `writing-great-skills`         | 3     | knowledge | Skill-writing conventions and vocabulary                                                                                   |
| `gitnexus-cli`                 | 1     | code      | Running the GitNexus CLI — analyze, status, clean, wiki                                                                    |
| `gitnexus-debugging`           | 1     | code      | "Why is X failing?", "Where does this error come from?"                                                                    |
| `gitnexus-exploring`           | 1     | code      | "How does X work?", "Show me the auth flow"                                                                                |
| `gitnexus-guide`               | 1     | code      | What GitNexus tools exist; graph schema; how to query                                                                      |
| `gitnexus-impact-analysis`     | 1     | code      | "What breaks if I change X?", "Is this safe to edit?"                                                                      |
| `gitnexus-pr-review`           | 1     | code      | Reviewing a PR — risk of merging, missing test coverage                                                                    |
| `gitnexus-refactoring`         | 1     | code      | Rename, extract, split, move, restructure                                                                                  |
| `animate`                      | 2     | design    | Building an animation from scratch                                                                                         |
| `animation-vocabulary`         | 1     | design    | "What's it called when…?" — naming a motion effect                                                                         |
| `apple-design`                 | 1     | design    | Gesture UI, spring animation, translucency, typography                                                                     |
| `emil-design-eng`              | 1     | design    | Component polish and motion philosophy                                                                                     |
| `find-animation-opportunities` | 1     | design    | "What could be animated here?" — read-only proposal                                                                        |
| `improve-animations`           | 3     | design    | Auditing a codebase's motion; produces a prioritized plan                                                                  |
| `review-animations`            | 2     | design    | Reviewing motion code against a craft bar                                                                                  |
| `pick-ui-library`              | 1     | design    | Choosing a library for a frontend task                                                                                     |
| `ask-sonner`                   | 2     | design    | Wiring Sonner toasts                                                                                                       |
| `baoyu-design`                 | 793   | artifact  | HTML artifacts: decks, mockups, diagrams, résumés. Largest bundle here; ships its own agent tree and `gen-pptx` toolchain. |
| `officecli`                    | 1     | artifact  | `.docx` / `.xlsx` / `.pptx` authoring and proofreading                                                                     |
| `clickup`                      | 1     | workflow  | ClickUp tasks and sprints via the `cup` CLI                                                                                |
| `release-skills`               | 1     | workflow  | Version bump, changelog, GitHub Release                                                                                    |
| `find-skills`                  | 1     | workflow  | "Find a skill for X"                                                                                                       |
| `first-principles-teaching`    | 1     | teaching  | "What is X for Y", "walk me through X"                                                                                     |

## Which direction needs which

| Direction   | Required                                                 | Notes                                                                                    |
| ----------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `--code`    | 7 × `gitnexus-*`                                         | Checked by `setup.sh`; all 7 are reference material for the MCP tools                    |
| `--noncode` | `open-knowledge-discovery`, `open-knowledge-write-skill` | `ok init` also installs these machine-wide itself, so a `--noncode` run self-heals a gap |

Everything else is available in both directions. Group is a convenience, not a gate.

## Claude-Code-only skills (not in this hub)

`fliphtml5-downloader` and `graphify` live in `~/.claude/skills/` only. They do **not**
load in Codex, OpenCode, Pi, or Copilot. Move the folder to `~/.agents/skills/` and every
agent picks it up.

## Why no per-project install step

Copying these into each project would create 25 × N copies that drift, and a
`skills-lock.json` per repo to reconcile them. The hub plus per-agent projections gives
the same reach with one copy to maintain. This is the same model Trellis uses for its own
skills (`.agents/skills/` as source, `.claude/` + `.pi/` as projections).

Trade-off: a project cannot pin a skill version. If a global skill changes under you, the
next session behaves differently. For a stable convention document, copy it into the repo.

## Verifying presence

``` bash
ls ~/.agents/skills/ | wc -l          # expect 25
ls -d ~/.agents/skills/gitnexus-guide  # per-direction check
```

Or let the script tell you:

``` bash
setup.sh --code      # warns and names any missing skill
```
