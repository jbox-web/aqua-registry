# jbox-web aqua registry

[![CI](https://github.com/jbox-web/aqua-registry/actions/workflows/ci.yml/badge.svg)](https://github.com/jbox-web/aqua-registry/actions/workflows/ci.yml)
[![aqua](https://img.shields.io/badge/tool-aqua-blue?logo=aqua)](https://aquaproj.github.io/)
[![mise](https://img.shields.io/badge/backend-mise-green?logo=rust)](https://mise.jdx.dev/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A custom [aqua](https://aquaproj.github.io/) registry that replicates the `vfox-*` mise plugins
published under the [jbox-web](https://github.com/jbox-web) org. It defines 30 CLI tools
(observability/infra binaries plus jbox-web internal tools) as aqua `github_release` /
`http` packages, with the same binaries, checksum verification, and platform coverage the
vfox plugins provided.

The root `registry.yaml` is **generated** — see [Maintaining the registry](#maintaining-the-registry)
before touching anything under `pkgs/`.

## Consumption: mise's aqua backend

The real consumer is [mise](https://mise.jdx.dev)'s aqua backend, not aqua itself. Point mise at
this repository via `aqua.registries` and it will check our `registry.yaml` before the baked-in
official aqua registry.

**Declarative (`mise.toml`):**

```toml
[settings]
aqua.registries = ["https://github.com/jbox-web/aqua-registry"]

[tools]
"aqua:prometheus/prometheus" = "3.5.1"
```

**Imperative:**

```bash
MISE_AQUA_REGISTRIES=https://github.com/jbox-web/aqua-registry mise use -g aqua:prometheus/prometheus@3.5.1
```

Under the hood mise downloads the root `registry.yaml` from this repo and resolves
`aqua:<owner>/<repo>` references against it before falling back to the official registry baked
into mise. This **replaces the old vfox pattern**:

```bash
# before (vfox plugin)
mise plugin install prometheus https://github.com/jbox-web/vfox-prometheus
mise use -g prometheus@3.5.1

# now (aqua backend, this registry)
mise use -g aqua:prometheus/prometheus@3.5.1
```

(Aqua-native consumption via a `github_content` registry entry in an aqua policy file is also
possible, but it is not how jbox-web's Docker images use this repository.)

## Tool index

All references below are `aqua:<repo_owner>/<repo_name>` as declared in `registry.yaml`.

### Observability

| Tool | Reference |
| --- | --- |
| Prometheus | `aqua:prometheus/prometheus` |
| Alertmanager | `aqua:prometheus/alertmanager` |
| Loki | `aqua:grafana/loki` |
| Promtail | `aqua:grafana/promtail` |
| OpenObserve | `aqua:openobserve/openobserve` |
| nginx-prometheus-exporter | `aqua:nginx/nginx-prometheus-exporter` |
| redis_exporter | `aqua:oliver006/redis_exporter` |
| pgbouncer_exporter | `aqua:prometheus-community/pgbouncer_exporter` |
| postgres_exporter | `aqua:prometheus-community/postgres_exporter` |

### Infra / platform

| Tool | Reference |
| --- | --- |
| yq | `aqua:mikefarah/yq` |
| frankenphp | `aqua:php/frankenphp` |
| composer | `aqua:composer/composer` |
| seaweedfs | `aqua:seaweedfs/seaweedfs` |
| mailpit | `aqua:axllent/mailpit` |
| go-crond | `aqua:webdevops/go-crond` |
| dnscontrol | `aqua:StackExchange/dnscontrol` |
| infisical | `aqua:Infisical/cli` |

### Security / certificates

| Tool | Reference |
| --- | --- |
| step-ca | `aqua:smallstep/certificates` |
| step | `aqua:smallstep/cli` |
| sentry-cli | `aqua:getsentry/sentry-cli` |
| lego | `aqua:go-acme/lego` |

### Dev tooling

| Tool | Reference |
| --- | --- |
| golangci-lint | `aqua:golangci/golangci-lint` |
| goreleaser | `aqua:goreleaser/goreleaser` |
| crystalline | `aqua:elbywan/crystalline` |

### jbox-web internal tools

| Tool | Reference |
| --- | --- |
| apt-larder | `aqua:jbox-web/apt-larder` |
| docker-health | `aqua:jbox-web/docker-health` |
| envtpl | `aqua:jbox-web/envtpl.cr` |
| netbox-extractor | `aqua:jbox-web/netbox-extractor` |
| squarectl | `aqua:jbox-web/squarectl` |
| stacker | `aqua:jbox-web/stacker` |

## Notes

- **composer** (`aqua:composer/composer`) installs a PHP `.phar`, not a native binary. It
  installs fine through this registry, but running it (`composer --version`) requires a `php`
  runtime on `PATH`.
- **openobserve** (`aqua:openobserve/openobserve`) is a `type: http` package: upstream stopped
  publishing GitHub Releases, so binaries are fetched from `downloads.openobserve.ai` while
  available versions are still listed from GitHub tags.

## Maintaining the registry

- Package sources live one per upstream repo, under `pkgs/<upstream-owner>/<upstream-repo>/registry.yaml`.
- The root `registry.yaml` is **generated** by `scripts/build-registry.sh` from everything under
  `pkgs/`. Never hand-edit the root file — regenerate it after any change under `pkgs/`.
- Do **not** use `aquaproj/registry-tool` (`argd`) to scaffold or generate packages: it is built
  to contribute to the official `aquaproj/aqua-registry` and pulls in the entire upstream
  registry. Use aqua's own `aqua gr <owner>/<repo>` (prints a package template to stdout, no git
  operations) plus `scripts/build-registry.sh` instead.

## Local testing

Test a package against a freshly regenerated local registry without touching the published one:

```bash
MISE_AQUA_REGISTRIES="file://$PWD" MISE_AQUA_REGISTRY_CACHE_TTL=0 mise x "aqua:<repo>@<ver>" -- <cmd>
```
