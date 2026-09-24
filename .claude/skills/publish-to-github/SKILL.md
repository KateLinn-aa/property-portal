---
name: publish-to-github
description: Publishes this project's sibling repos (property-portal-api, property-portal-app, property-portal-mobile) plus the root project to GitHub as public repositories, wiring the root up with git submodules pointing at each sibling. Use this whenever the user asks to publish, push, or put the project (or "all the repos", "the sibling projects", "api/app/mobile repos") on GitHub, make them public, or set up the root project with submodules. Also use it for re-running a publish after new commits land in any of the repos — it is safe to invoke repeatedly.
---

# Publish to GitHub

This project is four separate git repos: three sibling repos (API, web app,
mobile) plus a root repo that ties them together as git submodules. This
skill publishes all four to GitHub as **public** repositories under the
authenticated `gh` account, using `gh repo create` + `git push` (no GitHub
Claude Code plugin is assumed — if one becomes available in a future session,
prefer it over shelling out to `gh`, but the underlying steps are the same).

## Before running anything

This creates real public GitHub repositories and pushes real code — treat it
like any other "publish public content" action: **state the exact plan and
get an explicit yes in chat before running the script**, even if a past
conversation already discussed this. A skill can be invoked by someone with
no memory of that earlier discussion, so the confirmation has to happen here,
every time. Tell the user:

- which GitHub account it will publish under (run `gh api user --jq '.login'`
  to show the real account, don't guess)
- the exact 4 repo names it will create (root + 3 siblings)
- that all 4 will be **public**
- that this is close to a one-way door: once pushed, code and history are
  publicly visible immediately (a repo can be deleted or made private
  afterward, but anyone could have already cloned it in the meantime)

Only proceed once the user confirms.

## Preconditions

Each sibling directory must already be a local git repo on branch `main`
with at least one commit — this skill publishes existing work, it doesn't
create it. If a sibling isn't committed yet, stop and say so rather than
committing on its behalf (uncommitted work might be intentional, e.g. the
user is still mid-change).

Check `gh auth status` first. If not authenticated, stop and tell the user to
run `gh auth login` themselves — don't attempt to authenticate on their
behalf.

## Running it

The actual git/gh sequence is bundled as a script because it's mechanical and
benefits from being deterministic rather than re-derived each time:

```bash
bash .claude/skills/publish-to-github/scripts/publish.sh \
  "<root-dir>" "<repo-prefix>" \
  <sibling-dir-1> <sibling-dir-2> <sibling-dir-3> ...
```

- `<root-dir>`: absolute path to the project root (the directory that
  contains the sibling directories and will itself become the submodule
  parent repo).
- `<repo-prefix>`: the name to publish the root repo under (e.g.
  `property-portal`). Also used to label log output — it does not rename the
  siblings.
- Sibling args: the directory names to publish, relative to `<root-dir>`.
  Each publishes under its own directory name by default; append `:name` to
  publish under a different GitHub repo name, e.g. `property-portal-api:api`.

For this project specifically, that's:

```bash
bash .claude/skills/publish-to-github/scripts/publish.sh \
  "$(pwd)" property-portal \
  property-portal-api property-portal-app property-portal-mobile
```

The script:

1. For each sibling: creates a public GitHub repo matching its name (unless
   an `origin` remote already exists — then it just pushes), and pushes
   `main`.
2. For the root: `git init -b main` if it isn't a repo yet, writes a
   `.gitignore` if missing, adds each sibling as a `git submodule` pointing
   at its **GitHub URL** (not a local path — the whole point is that clones
   fetch the real remotes) unless it's already registered as one, commits,
   creates/publishes the root's own public repo, and pushes.

It's idempotent — re-running after some repos are already published skips
the steps already done instead of erroring or duplicating remotes/commits.

## After running

Report the final GitHub URL for all 4 repos (the script prints them at the
end) so the user has them to hand. If anything failed partway through (e.g.
a `gh repo create` hit a name collision), say exactly which repo and why,
rather than silently retrying with a different name — repo naming is a user
decision, not one to make unilaterally.
