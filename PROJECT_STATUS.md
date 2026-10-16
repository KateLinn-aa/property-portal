# Project Status

Read this first, then [SPEC.md](SPEC.md) for the original spec. Each sub-repo also has its own
README with repo-specific detail: [property-portal-api/README.md](property-portal-api/README.md),
[property-portal-app/README.md](property-portal-app/README.md),
[property-portal-mobile/README.md](property-portal-mobile/README.md).

## What this is

A property portal for Myanmar (Yangon, Mandalay, Bago) — buy/sell/rent listings, public search with
no login required, any registered user can post. Four separate git repos, linked as submodules from
this root:

| Repo | Status | GitHub |
|---|---|---|
| `property-portal-api` | Done — Express + Prisma 7 (SQLite) REST API | [KateLinn-aa/property-portal-api](https://github.com/KateLinn-aa/property-portal-api) |
| `property-portal-app` | Done — React + Vite web frontend | [KateLinn-aa/property-portal-app](https://github.com/KateLinn-aa/property-portal-app) |
| `property-portal-mobile` | Bare Expo scaffold only — implementation deliberately deferred | [KateLinn-aa/property-portal-mobile](https://github.com/KateLinn-aa/property-portal-mobile) |
| (this root) | Ties the three together as submodules | [KateLinn-aa/property-portal](https://github.com/KateLinn-aa/property-portal) |

All work is on each repo's `main` branch, clean working tree, fully pushed — nothing is stuck on an
unmerged branch.

## Running everything locally

```bash
# API
cd property-portal-api
npm install
cp .env.example .env
npx prisma migrate dev
npx prisma db seed
npm run dev          # http://localhost:4000

# Web app (separate terminal)
cd property-portal-app
npm install
cp .env.example .env   # VITE_API_URL defaults to http://localhost:4000
npm run dev           # http://localhost:5173
```

Demo logins: `demo.owner@example.com` / `DemoPass123!` (regular user, owns 3 listings) and
`demo.admin@example.com` / `DemoPass123!` (admin — `/admin` dashboard).

Mobile: `cd property-portal-mobile && npm install && npx expo start` — just shows a placeholder
screen, nothing functional yet.

## Moving to a new machine (e.g. copying this folder to a Mac)

- **`node_modules` will not work across OS/architecture — delete and reinstall.** Several
  dependencies have native bindings compiled for the machine they were installed on: `better-sqlite3`
  (API, via Prisma's driver adapter), Tailwind v4's oxide engine and Vite's rolldown binaries (web
  app), and Expo/Metro's native tooling (mobile). A `node_modules` folder built on Windows will not
  load on macOS ARM64. After copying, run `npm install` fresh in each of the three sub-repos — don't
  reuse the copied `node_modules`.
- **`.env` files are gitignored but will survive a raw folder copy** (unlike a fresh `git clone`,
  which won't have them at all). Their contents are machine-agnostic — relative file paths and
  `localhost` URLs — so they should keep working unchanged.
- **`gh` CLI auth does not travel with the folder** — it's stored in the OS keychain/config, not this
  project. Run `gh auth login` on the new machine if you want to keep using the `publish-to-github`
  skill (`.claude/skills/publish-to-github/`).
- **Simpler alternative to copying the folder**: since everything is already pushed, consider just
  running `git clone --recurse-submodules https://github.com/KateLinn-aa/property-portal.git` on the
  new machine instead. That sidesteps the `node_modules` problem entirely, at the cost of losing the
  seeded `dev.db` and any uploaded photos (those aren't committed — re-run `prisma db seed` after).
- Ports used locally: API `4000`, web dev server `5173`, mobile Metro bundler `8081`. All need to be
  free on the new machine (should be, on a clean install).
- Node `v25.9.0` was used for this session; no `engines` constraint is set in any `package.json`, so
  a reasonably recent Node should work, but that exact version is the known-good one.

## Deviations from SPEC.md (things that changed during implementation)

- **shadcn/ui preset**: SPEC.md's `--preset b7ClNFsdU` instruction turned out to be a real, resolvable
  preset (confirmed via the CLI's `/init` network call) — but it required the `--base base` flag to
  actually apply; without it, the CLI silently fell back to a Radix-based variant instead. The app
  runs on `base-luma` (Base UI primitives, Phosphor icons, Inter font, `mist` base color) — not the
  more common Radix/Lucide combo most shadcn docs/examples assume. Keep that in mind when adding new
  shadcn components (`npx shadcn@latest add <name> --overwrite`, from inside `property-portal-app`).
- **Base UI's `Select.Value`** does not auto-derive a label from the matching `Select.Item`'s
  children the way Radix's did — it shows the raw value unless `Select.Root` is given an `items` map
  (`{value, label}` pairs). Every `<Select>` in the app passes `items=` for this reason. If you add a
  new one and forget `items`, it'll silently show raw enum values instead of labels.
- **Prisma 7** requires a driver adapter (`@prisma/adapter-better-sqlite3`) rather than a bare
  `url = env("DATABASE_URL")` connection — see `property-portal-api/README.md`'s Prisma 7 section.
- The API runs on port **4000**, not 3001 as an early draft of the web app's README briefly (and
  incorrectly) stated — already fixed, just flagging in case it resurfaces in old notes anywhere.
- An admin role/dashboard (`/admin`, `UserRole.ADMIN`) and a light/dark mode toggle (`next-themes`)
  were added beyond the original SPEC.md scope, at the user's request mid-build.
- Mobile app implementation was deferred per SPEC.md §11 — the repo is a bare placeholder scaffold.

## Useful commands

```bash
# Re-publish to GitHub after new local commits (safe to re-run, skips what's already done)
# — invoke the publish-to-github skill, or run its script directly:
bash .claude/skills/publish-to-github/scripts/publish.sh "$(pwd)" property-portal \
  property-portal-api property-portal-app property-portal-mobile
```
