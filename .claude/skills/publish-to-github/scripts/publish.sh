#!/usr/bin/env bash
# Publishes a multi-repo project to GitHub: one public repo per sibling
# directory, plus a root repo that links them as git submodules.
#
# Usage:
#   publish.sh <root-dir> <repo-prefix> <sibling-dir>[:<repo-name>] [<sibling-dir>[:<repo-name>] ...]
#
# Example:
#   publish.sh "/path/to/project" property-portal \
#     property-portal-api property-portal-app property-portal-mobile
#
# Each sibling arg names a directory under <root-dir> that is already a git
# repo on branch `main` with at least one commit. <repo-name> defaults to the
# directory's own basename if omitted. The root repo is created/published as
# <repo-prefix> (e.g. "property-portal"), with each sibling added as a
# submodule pointing at its own GitHub URL.
#
# Idempotent: safe to re-run. Existing remotes/submodules/repos are detected
# and skipped rather than recreated or duplicated.

set -euo pipefail

ROOT_DIR="$1"; shift
REPO_PREFIX="$1"; shift
SIBLINGS=("$@")

if [ "${#SIBLINGS[@]}" -eq 0 ]; then
  echo "error: no sibling directories given" >&2
  exit 1
fi

GH_USER="$(gh api user --jq '.login')"
echo "Publishing as GitHub user: $GH_USER"

# --- helpers -----------------------------------------------------------

# Creates <name> as a public GitHub repo for the git repo at <path> (if it
# doesn't already have an origin remote), then pushes main. Prints the repo's
# https URL on success.
publish_repo() {
  local path="$1" name="$2"
  local url

  pushd "$path" >/dev/null

  if git remote get-url origin >/dev/null 2>&1; then
    echo "[$name] origin already set, pushing..." >&2
  else
    echo "[$name] creating public repo $GH_USER/$name..." >&2
    gh repo create "$name" --public --source=. --remote=origin >&2
  fi

  git push -u origin main >&2
  url="https://github.com/$GH_USER/$name"
  popd >/dev/null

  echo "$url"
}

# --- siblings ------------------------------------------------------------

declare -A SIBLING_URLS

for entry in "${SIBLINGS[@]}"; do
  dir="${entry%%:*}"
  name="${entry#*:}"
  [ "$name" = "$entry" ] && name="$dir"   # no ":" override given

  path="$ROOT_DIR/$dir"
  if [ ! -d "$path/.git" ]; then
    echo "error: $path is not a git repo (run git init -b main and commit first)" >&2
    exit 1
  fi

  url="$(publish_repo "$path" "$name")"
  SIBLING_URLS["$dir"]="$url"
done

# --- root repo -------------------------------------------------------------

pushd "$ROOT_DIR" >/dev/null

if [ ! -d ".git" ]; then
  echo "[$REPO_PREFIX] initializing root git repo..."
  git init -b main
fi

if [ ! -f .gitignore ]; then
  cat > .gitignore <<'EOF'
node_modules/
dist/
.env
.env.local
*.db
*.db-journal
*.log
.DS_Store
EOF
fi

for entry in "${SIBLINGS[@]}"; do
  dir="${entry%%:*}"
  url="${SIBLING_URLS[$dir]}"
  submodule_url="${url}.git"

  if git config --file .gitmodules --get "submodule.$dir.url" >/dev/null 2>&1; then
    echo "[$REPO_PREFIX] $dir already a submodule, skipping"
    continue
  fi

  echo "[$REPO_PREFIX] adding $dir as submodule -> $submodule_url"
  git submodule add "$submodule_url" "$dir"
done

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Publish root project with submodules

Co-Authored-By: Claude <noreply@anthropic.com>"
else
  echo "[$REPO_PREFIX] nothing new to commit"
fi

root_url="$(publish_repo "$ROOT_DIR" "$REPO_PREFIX")"

popd >/dev/null

# --- summary -----------------------------------------------------------

echo
echo "Published:"
echo "  root:   $root_url"
for entry in "${SIBLINGS[@]}"; do
  dir="${entry%%:*}"
  echo "  $dir: ${SIBLING_URLS[$dir]}"
done
