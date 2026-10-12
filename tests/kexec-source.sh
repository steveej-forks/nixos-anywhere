#!/usr/bin/env bash
set -euo pipefail

installer=$1
test_root=$(mktemp -d)
cleanup() {
  local status=$?
  if [[ $status == 0 ]]; then
    rm -rf "$test_root"
  else
    printf 'Failed fixture retained: %s\n' "$test_root" >&2
  fi
}
trap cleanup EXIT
counterparts="$test_root/bin"
mkdir -p "$counterparts"
counterpart="$(cd "$(dirname "$0")" && pwd)/kexec-counterpart.sh"
for command in bash dirname mktemp rm mkdir cat touch grep timeout awk xargs; do
  ln -s "$(command -v "$command")" "$counterparts/$command"
done
for command in ssh ssh-keygen ssh-copy-id curl nix wget kexec setsid; do
  ln -s "$counterpart" "$counterparts/$command"
  test -x "$counterparts/$command"
done
export PATH="$counterparts"
export HOME="$test_root/home"
mkdir -p "$HOME"
unset SSH_PRIVATE_KEY KEXEC_PATH_OR_URL

run_case() {
  export KEXEC_FIXTURE="$test_root/$1" KEXEC_ARCH="$2" KEXEC_WGET=y KEXEC_CURL=n
  mkdir -p "$KEXEC_FIXTURE"
  shift 2
  if ! timeout 10 bash "$installer" --flake 'fixture#system' --build-on remote \
    --no-use-machine-substituters --phases kexec "$@" root@fixture.invalid \
    >"$KEXEC_FIXTURE/output" 2>&1; then
    cat "$KEXEC_FIXTURE/output" >&2
    return 1
  fi
  test -f "$KEXEC_FIXTURE/booted"
  test -s "$KEXEC_FIXTURE/remote-script"
}

assert_remote_url() {
  local expected
  printf -v expected '%q ' wget "$1" -O-
  grep -F -- "$expected | tar -xv --gzip" "$KEXEC_FIXTURE/remote-script"
  test ! -e "$KEXEC_FIXTURE/uploaded-tarball"
}

for architecture in x86_64 aarch64; do
  run_case "default-$architecture" "$architecture"
  assert_remote_url "https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-$architecture-linux.tar.gz"
done
printf 'PASS: native defaults for x86_64 and aarch64\n'
