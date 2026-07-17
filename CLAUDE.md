# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **custom [aqua](https://aquaproj.github.io/) registry** (`jbox-web/aqua-registry`) that
replicates the 30 `vfox-*` mise plugins from the `jbox-web` org. Each package installs a single
CLI tool released on GitHub (observability/infra binaries: prometheus, loki, yq, step, frankenphp,
exporters, plus jbox-web internal tools), with the same binaries, checksum verification, and
platform coverage the vfox plugins provided.

The migration is complete: all 30 packages are defined under `pkgs/` and inlined into the root
`registry.yaml`. When adding or fixing a tool, follow the per-tool workflow (procedure P) below;
`README.md` documents the consumption path and the full tool index.

## Architecture (critical invariants)

- **The root `registry.yaml` is a GENERATED monolith — never hand-edit it.** aqua registry files
  have no `import` field, so every package is inlined into one file. Regenerate it with
  `./scripts/build-registry.sh` after ANY edit under `pkgs/`.
- **Per-package sources live under `pkgs/<upstream-owner>/<upstream-repo>/`**, classified by the
  **upstream** owner (not `jbox-web`):
  - `registry.yaml` — the package definition (source of truth, hand-edited)
  - No `pkg.yaml`, `aqua.yaml`, or `policy.yaml` — the registry is consumed through mise, not aqua-native.
- Packages are `type: github_release`, with two exceptions: `openobserve` is `type: http` (upstream
  stopped publishing GitHub Releases, so binaries come from `downloads.openobserve.ai` while versions
  are still listed from GitHub tags), and `composer` is a `github_release` package whose asset is
  downloaded via a `type: http` override (the `.phar`).
- **Consumption path (the real target): mise's aqua backend.** `MISE_AQUA_REGISTRIES` points mise at this
  registry (`file://$PWD` locally, the GitHub repo URL in CI/Docker); mise reads the root `registry.yaml`
  before the baked-in official one, so `mise x aqua:<repo>@<ver> -- <cmd>` (or a `[tools]` entry) installs
  our definition. The smoke test drives that exact path — the equivalent of the vfox `mise-tasks/test`.
- **One upstream repo, two tools:** `grafana/loki` backs both `loki` and `promtail`. aqua keys a
  package by unique `name:`, so promtail is a second package (`name: grafana/promtail`) with the
  same `repo_owner`/`repo_name` but a distinct `asset`/`files`.

## Toolchain (via mise, not curl|bash)

`Brewfile` pins `bash` + `mise`; root `mise.toml` pins `aqua` only. **Prefix every aqua command with
`mise exec -- `.**

> **Do NOT use `aquaproj/registry-tool` (`argd scaffold` / `argd generate-registry`).** It is built to
> *contribute to the official `aquaproj/aqua-registry`*: it fetches the entire upstream registry and
> branches off its HEAD, polluting this standalone repo with ~1500 packages. Use only aqua's own
> `aqua gr` (prints a package template to stdout, zero git) plus `scripts/build-registry.sh`.

```bash
brew bundle --file=Brewfile        # install bash + mise (idempotent)
mise install                       # install aqua
export GITHUB_TOKEN=$(gh auth token)   # avoid GitHub API rate limits during scaffold
```

## Per-tool workflow (procedure P)

Adding/fixing a tool follows this exact loop (per-tool asset/checksum/version details are reconciled
against the corresponding `vfox-*` plugin — see "Reconciliation source of truth" below):

```bash
# P1 scaffold from the real GitHub release (a template — expect to fix it in P2)
mkdir -p pkgs/<owner>/<repo>
mise exec -- aqua gr <owner>/<repo> > pkgs/<owner>/<repo>/registry.yaml

# P2 reconcile pkgs/<owner>/<repo>/registry.yaml against the vfox plugin:
#    - asset/format (tarball vs raw vs .zip/.gz/.phar)
#    - files (name + src) for renamed / nested binaries (and extra binaries, e.g. promtool)
#    - checksum (file name + algorithm), or omit when the vfox plugin fetches none
#    - supported_envs + replacements/overrides matching the vfox get_platform() map

# P3 regenerate the monolith
./scripts/build-registry.sh

# (no P4/P5 — no consumer file; the version is passed inline to mise x below)

# P6 smoke test — MUST pass before the tool is done. Drives the real mise -> aqua-backend -> our-registry path.
# file://$PWD points mise at the freshly regenerated root registry.yaml; CACHE_TTL=0 forces a re-read after edits.
# Export GITHUB_TOKEN first to avoid version-listing rate limits.
MISE_AQUA_REGISTRIES="file://$PWD" MISE_AQUA_REGISTRY_CACHE_TTL=0 mise x "aqua:<owner>/<repo>@<version>" -- <acceptance-cmd>   # output must contain the version
```

A tool is done only when P6 passes. If it fails, fix `pkgs/<owner>/<repo>/registry.yaml`, rerun
P3 + P6 — do not proceed to the next tool.

## Reconciliation source of truth

For each tool, the corresponding `vfox-*` plugin is authoritative for behavior. Read:
- `lib/base.lua` (`get_filename`, `github_checksum_url`) — asset & checksum naming
- `lib/util.lua` (`get_platform`) — the exact os/arch token map → `supported_envs` / `replacements`

Do not add os/arch pairs the upstream does not publish. Do not fabricate a checksum where the vfox
plugin fetched none (e.g. composer, seaweedfs).

## Conventions

- One commit per tool, message `Add <tool> package` (imperative, no trailing period). Root
  `registry.yaml` is staged alongside the `pkgs/` change since it is regenerated.
- All deliverables (YAML, README, CI, commit messages) in English.
- Docker is not required: the smoke test runs `mise x` on the host. Cross-platform coverage comes
  from the CI matrix (`.github/workflows/ci.yml`, Linux/macOS × amd64/arm64).
