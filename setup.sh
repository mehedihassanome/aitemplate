#!/usr/bin/env bash
#
# aitemplate/setup.sh — bootstrap an AI-agent-ready project, in one of two directions.
#
#   --code      Trellis + GitNexus + iwe          → MCP: gitnexus, iwe
#   --noncode   Trellis + iwe + OpenKnowledge    → MCP: iwe, open-knowledge
#
# Both directions share: Trellis (process layer), iwe (knowledge graph), and the
# machine-wide skill collection in ~/.agents/skills/ (nothing to install per-project).
#
# Idempotent: safe to re-run. Detects existing .trellis / .gitnexus / .iwe / .ok
# and skips what is already there.
#
set -euo pipefail

# ────────────────────────────── defaults ──────────────────────────────
DEFAULT_PLATFORMS="claude,pi,codex,opencode"

# Skills a noncode (docs/design/research) project wants beyond the global set.
NONCODE_SKILLS="open-knowledge-discovery,open-knowledge-write-skill"
# Skills a code project wants beyond the global set.
CODE_SKILLS="gitnexus-guide,gitnexus-impact-analysis,gitnexus-debugging,gitnexus-exploring,gitnexus-refactoring,gitnexus-pr-review,gitnexus-cli"

DIRECTION=""          # code | noncode
AUTO_DIRECTION=0      # 1 = detect and use, when neither flag was passed
MACHINE=0
PLATFORMS=""
USER_NAME=""
NO_ANALYZE=0
NO_SEED=0
SEED_PACK="plain-notes"
FORCE=0
DRY_RUN=0

# ────────────────────────────── helpers ───────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_B=$'\033[1;34m'; C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'
  C_R=$'\033[1;31m'; C_D=$'\033[2m';   C_0=$'\033[0m'
else
  C_B=; C_G=; C_Y=; C_R=; C_D=; C_0=
fi

_info() { printf '%s▸%s %s\n' "$C_B" "$C_0" "$*"; }
_ok()   { printf '%s✓%s %s\n' "$C_G" "$C_0" "$*"; }
_warn() { printf '%s⚠%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
_die()  { printf '%s✗%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }
_step() { [[ $DRY_RUN -eq 1 ]] && printf '%s  [dry-run]%s %s\n' "$C_D" "$C_0" "$*" || true; }

_have() { command -v "$1" >/dev/null 2>&1; }

# _run <cmd...> — echo in dry-run, execute otherwise. Failure is never fatal here;
# each caller decides whether a missing tool is a warning or an error.
_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '%s  [dry-run]%s %s\n' "$C_D" "$C_0" "$*"
  else
    "$@"
  fi
}

_usage() {
  cat <<'EOF'
Usage: setup.sh [direction] [options]

Bootstraps an AI-agent-ready project in one of two directions.

  --code        Code project.   Trellis + GitNexus + iwe
                MCP servers: gitnexus, iwe
  --noncode     Docs / research / design project.  Trellis + iwe + OpenKnowledge
                MCP servers: iwe, open-knowledge
                Installs the OpenKnowledge authoring skills; seeds a starter
                knowledge base with `ok seed`.

  With no direction flag, the script detects one (see --auto below).
  Passing both --code and --noncode is an error.

Options:
  --machine               Also run first-time-per-machine setup first
                         (install global CLIs, MCP config, check global skills)
  --auto                  Detect the direction instead of asking. Never prompts.
                         Detection: git repo with a code extension -> code,
                         otherwise -> noncode. `--auto` is implied when stdin
                         is not a terminal.
  --platforms <a,b,c>     Trellis platforms (default: claude,pi,codex,opencode)
                         Any of: claude pi codex opencode cursor kilo kiro gemini
                         antigravity windsurf qoder codebuddy copilot droid
  --user <name>           Developer identity for trellis init
                         (default: git user.name, else $USER, else "developer")
  --no-analyze            Skip `gitnexus analyze` (code direction only)
  --no-seed               Skip `ok seed` (noncode direction only)
  --seed-pack <id>        Starter pack for `ok seed` (default: plain-notes)
                         One of: knowledge-base software-lifecycle codebase-wiki
                         plain-notes okf writing-pipeline entity-vault worldbuilding
                         (run `ok seed --list-packs` for descriptions)
  -f, --force             Re-sync platform skills even if .trellis exists
  -n, --dry-run           Print what would run, change nothing
  -h, --help              Show this help

Examples:
  setup.sh --code                     # a service, library, or app
  setup.sh --noncode                  # docs, research, or a design repo
  setup.sh --machine --code           # fresh machine + first code project
  setup.sh --noncode --no-seed        # noncode without the starter knowledge base
  setup.sh --code -n                  # see what would happen, run nothing
EOF
}

# ──────────────────────────── arg parsing ─────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --code)      [[ -n "$DIRECTION" ]] && _die "--code and --noncode are mutually exclusive"
                 DIRECTION="code"; shift ;;
    --noncode)   [[ -n "$DIRECTION" ]] && _die "--code and --noncode are mutually exclusive"
                 DIRECTION="noncode"; shift ;;
    --machine)   MACHINE=1;    shift ;;
    --auto)      AUTO_DIRECTION=1; shift ;;
    --platforms) PLATFORMS="$2";  shift 2 ;;
    --user)      USER_NAME="$2";  shift 2 ;;
    --no-analyze) NO_ANALYZE=1; shift ;;
    --no-seed)    NO_SEED=1;    shift ;;
    --seed-pack)  SEED_PACK="$2"; shift 2 ;;
    -f|--force)   FORCE=1;      shift ;;
    -n|--dry-run) DRY_RUN=1;    shift ;;
    -h|--help)    _usage; exit 0 ;;
    *) _die "unknown argument: $1 (try --help)" ;;
  esac
done

PLATFORMS="${PLATFORMS:-$DEFAULT_PLATFORMS}"

# ────────────────────── direction: detect if not given ────────────────
detect_direction() {
  # A git repo holding source files is a code project. Everything else is
  # treated as a documentation / research project.
  local code_ext
  code_ext=$(find . -maxdepth 3 \
    \( -name node_modules -o -name .git -o -name .venv -o -name vendor \
       -o -name target -o -name dist -o -name build \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
             -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
             -o -name '*.rb' -o -name '*.c' -o -name '*.cpp' -o -name '*.cs' \
             -o -name '*.swift' -o -name '*.kt' -o -name '*.php' -o -name '*.sh' \) \
    -print 2>/dev/null | head -1)
  [[ -n "$code_ext" ]] && echo "code" || echo "noncode"
}

if [[ -z "$DIRECTION" ]]; then
  if [[ -t 0 ]]; then
    detected="$(detect_direction)"
    printf 'No direction given. Detected: %s\n' "$detected"
    printf '  [1] code     — Trellis + GitNexus + iwe\n'
    printf '  [2] noncode  — Trellis + iwe + OpenKnowledge\n'
    printf 'Choose [1/2] (Enter = %s, q = quit): ' "$detected"
    read -r choice || choice="$detected"
    case "$choice" in
      1) DIRECTION="code" ;;
      2) DIRECTION="noncode" ;;
      q|Q) _die "quit — nothing was changed" ;;
      "") DIRECTION="$detected" ;;
      *) _die "not a valid choice: $choice" ;;
    esac
  else
    # No terminal (CI, pipe, agent): detect silently rather than hang on read.
    DIRECTION="$(detect_direction)"
    AUTO_DIRECTION=1
  fi
fi

[[ $AUTO_DIRECTION -eq 1 ]] && _info "Direction: $DIRECTION (${DIRECTION}-stack)"

# ──────────────────────── machine-mode (once) ─────────────────────────
if [[ $MACHINE -eq 1 ]]; then
  _info "Machine bootstrap (_run once per machine)"

  _have node || _die "node not found — install Node.js (LTS) first: https://nodejs.org"
  _have npm  || _die "npm not found — install Node.js first"

  ensure_npm_global() {
    local pkg="$1" bin="$2"
    if _have "$bin"; then
      _ok "$bin already installed"
    else
      _info "installing $pkg ..."
      _run npm install -g "$pkg"
    fi
  }

  # Trellis is used by both directions, so it is always required.
  ensure_npm_global "@mindfoldhq/trellis" "trellis"

  # iwe (knowledge graph) is used by both directions. It ships via cargo, not npm.
  if _have iwe; then
    _ok "iwe already installed"
  else
    if ! _have cargo; then
      _warn "iwe missing and cargo not found — install from https://iwe.md (cargo install iwe)"
    else
      _info "installing iwe (cargo install iwe) ..."
      _run cargo install iwe || _warn "iwe install failed — install later: cargo install iwe"
    fi
  fi

  if [[ "$DIRECTION" == "code" ]]; then
    ensure_npm_global "gitnexus" "gitnexus"
    # One-time: MCP servers (Claude/Codex/OpenCode/Cursor) + hooks + gitnexus skills.
    # Idempotent — merges into existing config files.
    _info "gitnexus setup (MCP, hooks, global gitnexus skills) ..."
    _run gitnexus setup || _warn "gitnexus setup reported issues (often means already configured)"
  else
    # OpenKnowledge ships as a desktop app + npm CLI.
    if _have ok; then
      _ok "open-knowledge CLI already installed"
    else
      _info "installing @inkeep/open-knowledge ..."
      _run npm install -g @inkeep/open-knowledge \
        || _warn "npm install failed — install later, or use the OpenKnowledge desktop app"
    fi
  fi

  # Global skill collections live in ~/.agents/skills/ and auto-apply to every
  # project once present. Detect rather than auto-install: the installer differs
  # per collection.
  if [[ -d "$HOME/.agents/skills" ]] && \
     { [[ -d "$HOME/.agents/skills/gitnexus-guide" ]] || [[ -d "$HOME/.agents/skills/open-knowledge-write-skill" ]]; }; then
    _ok "global skills present in ~/.agents/skills/ ($(find "$HOME/.agents/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') skills)"
  else
    _warn "global skills not found in ~/.agents/skills/"
    cat <<'NOTE'
       Install your usual global skill collections now, e.g. (verify for your setup):
         pi install git:github.com/mattpocock/skills
       Skills in ~/.agents/skills/ are auto-loaded by every agent in every
       project — no per-project _step needed.
NOTE
  fi

  _ok "Machine bootstrap done."
  echo
fi

# ─────────────────────────── per-project init ─────────────────────────
PROJ="$(pwd)"
_info "Project directory: $PROJ"

_have trellis || _die "trellis CLI missing — re-run with --machine, or: npm i -g @mindfoldhq/trellis"

# Developer identity
if [[ -z "$USER_NAME" ]]; then
  USER_NAME="$(git config user.name 2>/dev/null || true)"
  USER_NAME="${USER_NAME:-$USER}"
  USER_NAME="${USER_NAME:-developer}"
fi

# Build platform flags from comma list → --claude --pi --codex --opencode
platform_flags=()
IFS=',' read -ra _plats <<< "$PLATFORMS"
for _p in "${_plats[@]}"; do
  _p="${_p## }"; _p="${_p%% }"      # trim spaces
  [[ -z "$_p" ]] && continue
  platform_flags+=("--$_p")
done
[[ ${#platform_flags[@]} -eq 0 ]] && _die "no valid platforms parsed from: $PLATFORMS"

# ── 1. Trellis (process layer) — both directions ────────────────────────
if [[ -d ".trellis" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    _warn ".trellis exists — re-syncing platform skills with --force"
    _run trellis init "${platform_flags[@]}" -u "$USER_NAME" -y -f
  else
    _ok ".trellis already initialized (use --force to re-sync platform skills)"
  fi
else
  _info "trellis init  (platforms: $PLATFORMS, user: $USER_NAME)"
  _run trellis init "${platform_flags[@]}" -u "$USER_NAME" -y -s
fi

# ── 2. Shared helpers ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

write_if_absent() {
  local target="$1" src="$2"
  if [[ -e "$target" ]]; then
    _ok "$(basename "$target") already present (left untouched)"
  elif [[ ! -f "$src" ]]; then
    _warn "template missing: $src"
  else
    _run cp "$src" "$target"
    [[ $DRY_RUN -eq 1 ]] || _ok "wrote $(basename "$target")"
  fi
}

# iwe fixes its library scan at `init` and never rescans, so this must run
# AFTER ok seed has written the starter documents — otherwise iwe indexes an
# empty corpus and the seeded notes are invisible to it forever.
init_iwe() {
  if [[ -d ".iwe" ]]; then
    _ok ".iwe already initialized"
    return
  fi
  if _have iwe; then
    _info "iwe init  (markdown knowledge graph)"
    if _run iwe init --auto; then
      [[ $DRY_RUN -eq 1 ]] || _ok ".iwe/config.toml written"
    else
      _warn "iwe init failed — run \`iwe init --auto\` manually"
    fi
  else
    # Seed the config from the bundled template so .mcp.json still has a valid
    # target even before iwe is installed on this machine.
    _warn "iwe CLI missing — writing bundled .iwe/config.toml (install: cargo install iwe)"
    _run mkdir -p .iwe
    write_if_absent ".iwe/config.toml" "$SCRIPT_DIR/templates/iwe-config.toml"
  fi
}

# ── 3. MCP server registration ─────────────────────────────────────────
_info "MCP servers (direction: $DIRECTION)"
write_if_absent ".mcp.json" "$SCRIPT_DIR/templates/mcp-$DIRECTION.json"

if [[ "$DIRECTION" == "code" ]]; then
  # Claude Code reads .mcp.json directly. Codex and OpenCode need their own keys —
  # they do not read .mcp.json. Print the block rather than editing a user's
  # global config from a script.
  _have gitnexus || _warn "gitnexus CLI missing — \`gitnexus setup\` (or --machine) registers its MCP server"
fi

# ── 4. Direction-specific tools ───────────────────────────────────────
if [[ "$DIRECTION" == "code" ]]; then
  _have gitnexus || _die "gitnexus CLI missing — re-run with --machine, or: npm i -g gitnexus"
  if [[ $NO_ANALYZE -eq 1 ]]; then
    _info "skipping gitnexus analyze (--no-analyze)"
  elif [[ -d ".gitnexus" ]]; then
    _ok ".gitnexus index already present (run \`gitnexus analyze\` manually to refresh)"
  else
    _info "gitnexus analyze (indexing repo — first run can take a while)"
    _run gitnexus analyze || _warn "gitnexus analyze failed — retry manually with \`gitnexus analyze\`"
  fi
else
  # `ok init` scaffolds .ok/, registers the MCP server, and installs the
  # authoring skills. --no-mcp keeps it to the .ok/ scaffold only.
  if [[ -d ".ok" ]]; then
    _ok ".ok already initialized"
  elif _have ok; then
    _info "ok init  (OpenKnowledge knowledge base + authoring skills)"
    if [[ $NO_SEED -eq 1 ]]; then
      _run ok init --no-mcp || _warn "ok init failed — run \`ok init\` manually"
    else
      _run ok init || _warn "ok init failed — run \`ok init\` manually"
    fi
  else
    _warn "open-knowledge CLI missing — install @inkeep/open-knowledge, or use the desktop app"
  fi

  # ok init creates the config; ok seed adds a starter pack of documents.
  # --yes is required: ok seed prompts for confirmation, which cannot be
  # answered from a non-interactive run (CI, pipe, agent) and leaves the
  # project half-scaffolded.
  if [[ $NO_SEED -eq 1 ]]; then
    _info "skipping ok seed (--no-seed)"
  elif [[ $DRY_RUN -eq 1 ]]; then
    _info "ok seed (starter pack: $SEED_PACK)"
    _run ok seed --pack "$SEED_PACK" --yes || _warn "ok seed failed — optional, retry with \`ok seed\`"
  elif [[ ! -d ".ok" ]]; then
    _info "skipping ok seed (.ok/ was not created)"
  elif _have ok; then
    _info "ok seed (starter pack: $SEED_PACK)"
    _run ok seed --pack "$SEED_PACK" --yes || _warn "ok seed failed — optional, retry with \`ok seed --yes\`"
  fi
fi

# ── 5. iwe (knowledge layer) — after any content exists ───────────────
# Order matters: iwe scans once at init. In noncode the corpus is created by
# `ok seed`, so init must follow it or the library comes up empty.
init_iwe

# ── 6. Skill manifest ──────────────────────────────────────────────────
# The skills themselves are machine-wide in ~/.agents/skills/ and need no
# per-project install. This only records what the project expects, so a future
# agent can tell whether the environment is complete.
if [[ "$DIRECTION" == "code" ]]; then
  want_skills="$CODE_SKILLS"
else
  want_skills="$NONCODE_SKILLS"
fi

missing=()
IFS=',' read -ra _want <<< "$want_skills"
for _s in "${_want[@]}"; do
  [[ -d "$HOME/.agents/skills/$_s" ]] || missing+=("$_s")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  _ok "direction skills present in ~/.agents/skills/ ($(printf '%s' "$want_skills" | tr ',' ' '))"
else
  _warn "missing from ~/.agents/skills/: ${missing[*]}"
  _warn "  install them, or copy from a machine that has them"
fi

# ── 7. Gitignore hygiene ───────────────────────────────────────────────
# Only ignore what this direction actually produces, so a code repo is not told
# to ignore an .ok/ that will never exist.
_info "gitignore"
ignore_entries=(".trellis/workspace/")
if [[ "$DIRECTION" == "code" ]]; then
  ignore_entries+=(".gitnexus/")
else
  ignore_entries+=(".ok/cache/")
fi
for entry in "${ignore_entries[@]}"; do
  if [[ -e ".gitignore" ]] && grep -qxF "$entry" .gitignore 2>/dev/null; then
    : # already ignored
  elif [[ $DRY_RUN -eq 1 ]]; then
    printf '%s  [dry-run]%s append %s to .gitignore\n' "$C_D" "$C_0" "$entry"
  elif [[ -e ".gitignore" ]]; then
    printf '%s\n' "$entry" >> .gitignore
    _ok "gitignore: $entry"
  else
    : # no .gitignore yet; not this script's job to create one
  fi
done

# ────────────────────────────── done ──────────────────────────────────
_ok "Setup complete for: $PROJ  ($DIRECTION)"
cat <<EOF

  Direction:  $DIRECTION
  Process:    Trellis       .trellis/
  Knowledge:  iwe           .iwe/ + .mcp.json
EOF
if [[ "$DIRECTION" == "code" ]]; then
cat <<EOF
  Code:       GitNexus      .gitnexus/
  MCP:        gitnexus, iwe
EOF
else
cat <<EOF
  Collab:     OpenKnowledge .ok/
  MCP:        iwe, open-knowledge
EOF
fi
cat <<EOF

  Next steps:
EOF
if [[ "$DIRECTION" == "code" ]]; then
cat <<EOF
    • Index freshness matters: run \`gitnexus analyze\` after a big commit, and
      never skip \`gitnexus_impact\` before editing a symbol.
    • Commit the scaffolding:
        git add .trellis .claude .pi .codex .agents .mcp.json .iwe AGENTS.md CLAUDE.md
        git commit -m "chore: bootstrap trellis + gitnexus + iwe"
EOF
else
cat <<EOF
    • OpenKnowledge needs its server for collaborative writes:
        ok start           # required before write / checkpoint / restore_version
      \`ok lint\` and \`iwe schema validate\` are headless and work without it.
    • Commit the scaffolding:
        git add .trellis .claude .pi .codex .agents .mcp.json .iwe .ok AGENTS.md CLAUDE.md
        git commit -m "chore: bootstrap trellis + iwe + openknowledge"
EOF
fi
cat <<EOF
      (.gitnexus/, .trellis/workspace/, .ok/cache/ are gitignored on purpose)
    • Read the per-direction guide: docs/$DIRECTION.md
EOF
