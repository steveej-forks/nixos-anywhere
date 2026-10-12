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
for command in bash dirname mktemp rm mkdir cat touch grep timeout awk xargs cmp; do
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
  export KEXEC_FIXTURE="$test_root/$1" KEXEC_ARCH="$2"
  export KEXEC_WGET="${KEXEC_TEST_WGET-y}" KEXEC_CURL="${KEXEC_TEST_CURL-n}"
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

export KEXEC_PATH_OR_URL='https://fixture.invalid/custom-image.tar.gz'
run_case environment-url x86_64
assert_remote_url "$KEXEC_PATH_OR_URL"

KEXEC_TEST_WGET=n KEXEC_TEST_CURL=y run_case environment-remote-curl x86_64
printf -v expected_curl '%q ' curl --fail -Ss -L "$KEXEC_PATH_OR_URL"
grep -F -- "$expected_curl | tar -xv --gzip" "$KEXEC_FIXTURE/remote-script"
test ! -e "$KEXEC_FIXTURE/uploaded-tarball"

KEXEC_TEST_WGET=n KEXEC_TEST_CURL=n run_case environment-local-curl x86_64
printf '%s\0' --fail -Ss -L "$KEXEC_PATH_OR_URL" >"$KEXEC_FIXTURE/expected-curl-arguments"
cmp "$KEXEC_FIXTURE/expected-curl-arguments" "$KEXEC_FIXTURE/curl-arguments"
test -s "$KEXEC_FIXTURE/uploaded-tarball"

custom_file="$test_root/custom installer.tar.gz"
printf 'synthetic custom installer\n' >"$custom_file"
export KEXEC_PATH_OR_URL="$custom_file"
run_case environment-file x86_64
cmp "$custom_file" "$KEXEC_FIXTURE/uploaded-tarball"
test ! -e "$KEXEC_FIXTURE/curl-arguments"

explicit_url=https://fixture.invalid/explicit.tar.gz
run_case explicit-url x86_64 --kexec "$explicit_url"
assert_remote_url "$explicit_url"

export KEXEC_PATH_OR_URL=https://fixture.invalid/environment.tar.gz
run_case explicit-file x86_64 --kexec "$custom_file"
cmp "$custom_file" "$KEXEC_FIXTURE/uploaded-tarball"

export KEXEC_PATH_OR_URL=''
run_case empty-environment x86_64
assert_remote_url 'https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz'

export KEXEC_PATH_OR_URL=https://fixture.invalid/environment.tar.gz
run_case explicit-empty x86_64 --kexec ''
assert_remote_url 'https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz'
printf 'PASS: environment URL/file, explicit precedence and empty defaults\n'
