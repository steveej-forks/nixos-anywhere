{ lib
, runCommand
, bash
, coreutils
, gnugrep
, gawk
, findutils
, shellcheck
, shfmt
, nixos-anywhere
,
}:
let
  testSource = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./kexec-source.sh
      ./kexec-counterpart.sh
    ];
  };
in
runCommand "nixos-anywhere-kexec-source"
{
  nativeBuildInputs = [
    bash
    coreutils
    gnugrep
    gawk
    findutils
    shellcheck
    shfmt
  ];
}
  ''
    shellcheck -s bash ${../src/nixos-anywhere.sh} ${./kexec-source.sh} ${./kexec-counterpart.sh}
    shfmt -d -i 2 ${./kexec-source.sh} ${./kexec-counterpart.sh}
    bash -n ${../src/nixos-anywhere.sh} ${./kexec-source.sh} ${./kexec-counterpart.sh}
    cp ${testSource}/kexec-source.sh ${testSource}/kexec-counterpart.sh .
    chmod u+wx kexec-source.sh kexec-counterpart.sh
    patchShebangs kexec-source.sh kexec-counterpart.sh
    bash ./kexec-source.sh ${nixos-anywhere}/libexec/nixos-anywhere/nixos-anywhere.sh
    touch "$out"
  ''
