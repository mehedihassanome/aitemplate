#!/usr/bin/env bash
#
# aitemplate/setup.sh — bootstrap Trellis + GitNexus (+ skills) in any project.
#
# Two modes:
#   ./setup.sh                Per-project init (default): trellis init + gitnexus analyze
#   ./setup.sh --machine      First-time-per-machine extras FIRST, then per-project init.
#                            (installs global CLIs, runs `gitnexus setup` for MCP/hooks/skills,
#                             checks global skill collections)
#
# Idempotent: safe to re-run. Detects existing .trellis / .gitnexus and skips.
#
set -euo pipefail

# ────────────────────────────── defaults ──────────────────────────────
DEFAULT_PLATFORMS="claude,pi,codex,opencode"

MACHINE=0
PLATFORMS=""
USER_NAME=""
NO_ANALYZE=0
FORCE=0

# ────────────────────────────── helpers ───────────────────────────────
info() { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'EOF'
Usage: setup.sh [options]

Bootstraps Trellis + GitNexus (+ skills) in the current project directory.

Options:
  --machine                 Also run first-time-per-machine setup first
                            (install global CLIs, gitnexus setup, check global skills)
  --platforms <a,b,c>       Trellis platforms (default: claude,pi,codex,opencode)
                            Any of: claude pi codex opencode cursor kilo kiro gemini
                            antigravity windsurf qoder codebuddy copilot droid
  --user <name>             Developer identity for trellis init
                            (default: git user.name, else $USER, else "developer")
  --no-analyze              Skip `gitnexus analyze`
  -f, --force               Re-sync platform skills even if .trellis exists
                            (passes --force to `trellis init`)
  -h, --help                Show this help

Examples:
  setup.sh                                   # quick per-project init
  setup.sh --machine                         # fresh machine + first project (does everything)
  setup.sh --platforms claude,pi --user bob  # custom platforms + identity
EOF
}

# ──────────────────────────── arg parsing ─────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --machine)    MACHINE=1;    shift ;;
    --platforms)  PLATFORMS="$2";  shift 2 ;;
    --user)       USER_NAME="$2";  shift 2 ;;
    --no-analyze) NO_ANALYZE=1; shift ;;
    -f|--force)   FORCE=1;      shift ;;
    -h|--help)    usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

PLATFORMS="${PLATFORMS:-$DEFAULT_PLATFORMS}"

# ──────────────────────── machine-mode (once) ─────────────────────────
if [[ $MACHINE -eq 1 ]]; then
  info "Machine bootstrap (run once per machine)"

  have node || die "node not found — install Node.js (LTS) first: https://nodejs.org"
  have npm  || die "npm not found — install Node.js first"

  ensure_npm_global() {
    local pkg="$1" bin="$2"
    if have "$bin"; then
      ok "$bin already installed"
    else
      info "installing $pkg ..."
      npm install -g "$pkg"
    fi
  }
  ensure_npm_global "@earendil-works/pi-coding-agent" "pi"
  ensure_npm_global "@mindfoldhq/trellis"             "trellis"
  ensure_npm_global "gitnexus"                        "gitnexus"

  # GitNexus one-time config: MCP servers (Cursor/Claude/OpenCode/Codex) + hooks + skills.
  # Idempotent (merges into existing config files).
  info "gitnexus setup (MCP, hooks, global gitnexus skills) ..."
  gitnexus setup || warn "gitnexus setup reported issues (often means already configured)"

  # Global skill collections live in ~/.agents/skills/ and ~/.pi/agent/skills/ and are
  # auto-available to every project once present. Detect rather than auto-install,
  # because the exact installer for non-gitnexus sets (mattpocock, etc.) varies.
  if [[ -d "$HOME/.agents/skills" ]] && \
     { [[ -d "$HOME/.agents/skills/code-review" ]] || [[ -d "$HOME/.agents/skills/gitnexus-guide" ]]; }; then
    ok "global skills present in ~/.agents/skills/"
  else
    warn "global skill collections not found in ~/.agents/skills/"
    cat <<'NOTE'
       Install your usual global skill collections now, e.g. (verify the command for your setup):
         pi install git:github.com/mattpocock/skills
       Skills in ~/.agents/skills/ and ~/.pi/agent/skills/ are auto-loaded by pi
       in every project — no per-project step needed.
NOTE
  fi

  ok "Machine bootstrap done."
  echo
fi

# ─────────────────────────── per-project init ─────────────────────────
info "Project directory: $(pwd)"

have trellis  || die "trellis CLI missing — re-run with --machine, or: npm i -g @mindfoldhq/trellis"
have gitnexus || die "gitnexus CLI missing — re-run with --machine, or: npm i -g gitnexus"

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
[[ ${#platform_flags[@]} -eq 0 ]] && die "no valid platforms parsed from: $PLATFORMS"

# trellis init (idempotent)
if [[ -d ".trellis" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    warn ".trellis exists — re-syncing platform skills with --force"
    trellis init "${platform_flags[@]}" -u "$USER_NAME" -y -f
  else
    ok ".trellis already initialized (use --force to re-sync platform skills)"
  fi
else
  info "trellis init  (platforms: $PLATFORMS, user: $USER_NAME)"
  trellis init "${platform_flags[@]}" -u "$USER_NAME" -y -s
fi

# gitnexus analyze (build .gitnexus/ index)
if [[ $NO_ANALYZE -eq 1 ]]; then
  info "skipping gitnexus analyze (--no-analyze)"
elif [[ -d ".gitnexus" ]]; then
  ok ".gitnexus index already present (run \`gitnexus analyze\` manually to refresh)"
else
  info "gitnexus analyze (indexing repo — first run can take a while)"
  gitnexus analyze || warn "gitnexus analyze failed — retry manually with \`gitnexus analyze\`"
fi

# ────────────────────────────── done ──────────────────────────────────
ok "Setup complete for: $(pwd)"
cat <<EOF

Next steps:
  • Review generated files: .trellis/ (workflow.md, spec/), AGENTS.md, CLAUDE.md
  • Commit the scaffolding (paths trellis/gitnexus don't already gitignore):
      git add .trellis .claude .pi .codex .agents AGENTS.md CLAUDE.md
      git commit -m "chore: bootstrap trellis + gitnexus"
    (.gitnexus/ and .trellis/workspace/ are typically gitignored — check their .gitignore)
  • Start coding. In pi, the trellis-* and gitnexus-* skills are now available.
EOF
