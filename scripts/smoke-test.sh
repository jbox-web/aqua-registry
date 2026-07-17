#!/usr/bin/env bash
# Smoke test every package through mise's aqua backend against THIS registry —
# the equivalent of the vfox plugins' mise-tasks/test. Installs each pinned ref
# and asserts its version string appears in the tool's own --version output.
#
# NOTE: intentionally NO `set -e`. This harness is accumulate-and-report: it must
# run every check, collect all failures, emit a `::error::<ref>` per failure, and
# exit non-zero at the end. Under `errexit`, the `out=$(mise x ...)` capture below
# would abort the whole script on the first failing install — before the `if` that
# reports which package failed — yielding a bare exit code and zero diagnostics.
# GitHub runs inline `run:` steps under `bash -e {0}`; invoking this as a standalone
# script sidesteps that, and `set +e` here makes the intent explicit and regression-proof.
set +e
set -uo pipefail

cd "$(dirname "$0")/.."

# Point mise's aqua backend at this checked-out registry (before the baked-in official
# one), and force a re-read after edits. Both default for standalone/local runs; CI sets
# them at the job level (this leaves those values untouched).
export MISE_AQUA_REGISTRIES="${MISE_AQUA_REGISTRIES:-file://$PWD}"
export MISE_AQUA_REGISTRY_CACHE_TTL="${MISE_AQUA_REGISTRY_CACHE_TTL:-0}"
# Gates packages whose supported_envs excludes a leg of the CI matrix; empty when run locally.
MATRIX_OS="${MATRIX_OS:-}"

# `check <ref> <expected> <cmd...>` installs <ref> through mise's aqua backend and asserts
# <expected> appears in the command's combined output.
#
# Output is captured with `$(...)` rather than piped straight into `grep -q`: `grep -q` exits as
# soon as it sees a match, and if the producer (mise/the tool) is still writing more lines after
# the matching one, it can be killed by SIGPIPE — under `pipefail` that turns a real pass into a
# spurious failure. Capturing first (which waits for the process to finish) avoids the race.
#
# Combined stdout+stderr: several exporters (kingpin-based CLIs, e.g. nginx_exporter,
# pgbouncer_exporter, postgres_exporter) print --version to stderr, not stdout.
fail=0
check() {
  local ref="$1" expected="$2"; shift 2
  local out
  out=$(mise x "aqua:$ref" -- "$@" 2>&1)
  if ! grep -q -- "$expected" <<<"$out"; then
    echo "::error::$ref: expected '$expected' in output of: $*"
    echo "$out"
    fail=1
  fi
}

# Packages with no supported_envs (aqua default = broad: linux/darwin/windows, amd64/arm64)
# or with supported_envs covering all four matrix legs run unconditionally.
check "mikefarah/yq@4.52.4" 4.52.4 yq --version
check "prometheus/prometheus@3.5.1" 3.5.1 prometheus --version
check "smallstep/cli@0.30.2" 0.30.2 step version
check "prometheus/alertmanager@0.31.1" 0.31.1 alertmanager --version
check "goreleaser/goreleaser@2.14.3" 2.14.3 goreleaser --version
check "StackExchange/dnscontrol@4.36.1" 4.36.1 dnscontrol --version
check "axllent/mailpit@1.29.4" 1.29.4 mailpit version
check "smallstep/certificates@0.30.2" 0.30.2 step-ca version
check "golangci/golangci-lint@2.11.4" 2.11.4 golangci-lint --version
check "go-acme/lego@4.33.0" 4.33.0 lego --version
check "nginx/nginx-prometheus-exporter@1.5.1" 1.5.1 nginx_exporter --version
check "prometheus-community/pgbouncer_exporter@0.12.0" 0.12.0 pgbouncer_exporter --version
check "prometheus-community/postgres_exporter@0.19.1" 0.19.1 postgres_exporter --version
check "oliver006/redis_exporter@1.82.0" 1.82.0 redis_exporter --version
check "php/frankenphp@1.12.4" 1.12.4 frankenphp version
check "getsentry/sentry-cli@3.3.3" 3.3.3 sentry-cli --version
check "webdevops/go-crond@23.12.0" 23.12.0 go-crond --version
check "grafana/loki@3.5.12" 3.5.12 loki --version
check "grafana/promtail@3.5.12" 3.5.12 promtail --version
check "seaweedfs/seaweedfs@4.30" 4.30 weed version
check "jbox-web/apt-larder@1.0.0" 1.0.0 apt-larder --version
check "jbox-web/docker-health@1.3.0" 1.3.0 docker-health --version
check "jbox-web/envtpl.cr@1.6.0" 1.6.0 envtpl --version
check "jbox-web/netbox-extractor@1.0.1" 1.0.1 netbox-extractor --version
check "jbox-web/squarectl@1.6.0" 1.6.0 squarectl --version
check "jbox-web/stacker@1.2.0" 1.2.0 stacker --version
check "Infisical/cli@0.43.60" 0.43.60 infisical --version
check "openobserve/openobserve@0.70.0" 0.70.0 openobserve --version

# crystalline: supported_envs = [linux/amd64, darwin] — excludes linux/arm64, so skip on that leg
if [ "$MATRIX_OS" != "ubuntu-24.04-arm" ]; then
  check "elbywan/crystalline@0.18.0" 0.18.0 crystalline --version
fi

# composer.phar is a PHP script and needs a PHP runtime to actually execute (`composer --version`
# would fail with "command not found: php" on a runner with no PHP installed). Rather than adding
# a PHP setup step just for this one assertion, assert successful install/link instead of running it.
if ! mise x "aqua:composer/composer@2.10.1" -- true; then
  echo "::error::composer/composer@2.10.1: install/link failed"
  fail=1
fi

exit "$fail"
