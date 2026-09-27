#!/bin/bash
# kernel_fetch_probe.sh -- judge os2_kernel_fetch.sh both ways (DOC-1): the
# pin as committed is fetched and verified, and three wrong worlds are each
# refused for the reason it is wrong -- a digest the pin gets wrong, a
# version kernel.org never released, and a tarball on disk that is not the
# one pinned. The wrong worlds are scratch trees under $HOME; the
# repository's vendor/ is never altered, and the 142 MB tarball is linked,
# never copied. Output: zig-out/wsl/kernel_fetch_probe.txt
cd "$(dirname "$0")/.." || exit 1
R=$PWD
mkdir -p zig-out/wsl
LOG=zig-out/wsl/kernel_fetch_probe.txt
P=$HOME/harb-fetch-probe
(
  FAILS=0
  TARBALL=$(awk -F'`' '/^\| tarball \| `linux-/ {print $2; exit}' vendor/PIN.md)
  SUM=$(awk -F'`' '/^\| tarball \| `linux-/ {f=1} f && /^\| sha256 \|/ {print $2; exit}' vendor/PIN.md)
  echo "the pin: $TARBALL $SUM"
  rm -rf "$P"; mkdir -p "$P"

  # label, wanted exit, got exit, text the output must hold, output file
  verdict() {
    if [ "$3" = "$2" ] && grep -qF -- "$4" "$5"; then
      echo "PASS  $1 (exit $3)"
    else
      echo "FAIL  $1 (exit $3; wanted $2 and: $4)"
      sed 's/^/        /' "$5"
      FAILS=$((FAILS + 1))
    fi
  }
  # a tree with the script and a copy of the pin; the tarball linked
  scratch() {
    T=$P/$1
    mkdir -p "$T/experiment" "$T/vendor/linux"
    cp "$R/experiment/os2_kernel_fetch.sh" "$T/experiment/"
    cp "$R/vendor/PIN.md" "$T/vendor/"
    ln -s "$R/vendor/linux/$TARBALL" "$T/vendor/linux/$TARBALL"
  }

  bash experiment/os2_kernel_fetch.sh > "$P/control.out" 2>&1
  verdict "the pin as committed" 0 $? "kernel.org agrees with the pin" "$P/control.out"
  if [ "$(cat vendor/linux/PIN.txt)" = "$TARBALL $SUM" ]; then
    echo "PASS  PIN.txt records the pinned tarball"
  else
    echo "FAIL  PIN.txt says: $(cat vendor/linux/PIN.txt)"; FAILS=$((FAILS + 1))
  fi

  scratch digest
  F=${SUM:0:1}; if [ "$F" = 0 ]; then BAD=1${SUM:1}; else BAD=0${SUM:1}; fi
  sed -i "s/$SUM/$BAD/" "$P/digest/vendor/PIN.md"
  bash "$P/digest/experiment/os2_kernel_fetch.sh" > "$P/digest.out" 2>&1
  verdict "a digest the pin gets wrong" 1 $? "and the pin says $BAD -- refused" "$P/digest.out"

  scratch version
  sed -i "s/$TARBALL/linux-6.12.999.tar.xz/" "$P/version/vendor/PIN.md"
  bash "$P/version/experiment/os2_kernel_fetch.sh" > "$P/version.out" 2>&1
  verdict "a version kernel.org never released" 1 $? "kernel.org says nothing for linux-6.12.999.tar.xz" "$P/version.out"

  scratch tarball
  rm "$P/tarball/vendor/linux/$TARBALL"
  echo "not a kernel" > "$P/tarball/vendor/linux/$TARBALL"
  bash "$P/tarball/experiment/os2_kernel_fetch.sh" > "$P/tarball.out" 2>&1
  verdict "a tarball on disk that is not the one pinned" 1 $? "DIGEST MISMATCH -- refused" "$P/tarball.out"

  rm -rf "$P"
  echo "probes failed: $FAILS"
  [ "$FAILS" = 0 ]
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
