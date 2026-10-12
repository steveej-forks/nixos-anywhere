#!/usr/bin/env bash
set -euo pipefail

case "${0##*/}" in
ssh-keygen | ssh-copy-id)
  exit 0
  ;;
ssh)
  for argument in "$@"; do
    if [[ $argument == -G ]]; then
      printf 'user root\n'
      exit 0
    fi
  done
  case "${*: -1}" in
  --)
    cat >/dev/null
    installer=n
    if [[ -f $KEXEC_FIXTURE/booted ]]; then installer=y; fi
    printf '%s\n' "isArch=$KEXEC_ARCH" "isInstaller=$installer" \
      'isOs=Linux' 'isContainer=none' 'isRoot=y' 'hasIpv6Only=n' \
      'hasTar=y' 'hasCpio=y' 'hasSudo=n' 'hasDoas=n' \
      "hasWget=$KEXEC_WGET" "hasCurl=$KEXEC_CURL" 'hasSetsid=y'
    ;;
  "mkdir -p \"\$HOME/kexec\" && cat > \"\$HOME/kexec/nixos-anywhere-kexec.sh\"")
    cat >"$KEXEC_FIXTURE/remote-script"
    ;;
  "cat > \"\$HOME/kexec/kexec-tarball.tar.gz\"")
    cat >"$KEXEC_FIXTURE/uploaded-tarball"
    ;;
  "bash \"\$HOME/kexec/nixos-anywhere-kexec.sh\"")
    touch "$KEXEC_FIXTURE/booted"
    ;;
  '0')
    for argument in "$@"; do
      if [[ $argument == -T ]]; then exit 0; fi
    done
    exit 1
    ;;
  *)
    printf 'Unexpected synthetic SSH command: %q\n' "$@" >&2
    exit 1
    ;;
  esac
  ;;
curl)
  printf '%s\0' "$@" >"$KEXEC_FIXTURE/curl-arguments"
  printf 'synthetic tarball\n'
  ;;
*)
  printf 'Unexpected command: %s\n' "$0" >&2
  exit 1
  ;;
esac
