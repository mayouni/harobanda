#!/bin/bash
# advisories_scene.sh -- which kernel advisories reach which machine (ONEHOUR-1), judged against a pin.
#
#   bash experiment/advisories_scene.sh       -> zig-out/advisories_scene.txt, judged by machines/advisories.expected
#
# Two machines read the same six records (experiment/advisories/, FIXTURES written by hand in the shape of the
# kernel's own records -- not real advisories): qemu_egress, which declares a network and so compiles the IPv4
# stack, and qemu_hello, which declares none. The TCP flaw reaches the first and is not built into the second;
# the program filter's reaches both; the crypto socket's and the packet filter's reach neither; the flaw the pin
# moved past is fixed; a record that names no file cannot be told. Then the negatives, each of which must refuse
# with exit 1: another machine's list, a list of the kernel the pin held before, a directory that holds something
# that is not a record, a record that is not one; and the list itself put to the question -- the egress list with
# net/ipv4/tcp.c taken out turns its TCP answer to not-built, so the answer is the list's and not the record's.
#
# It needs each machine's list of compiled files, which its image build writes: run
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os2_image.sh qemu_egress   (and qemu_hello)
# first, after any change to the pin or to what those machines' kernels need. Seconds; no emulator.
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=zig-out/advisories_scene.txt
PIN=machines/advisories.expected
rm -f "$LOG"
HARB=zig-out/bin/harb.exe; [ -x "$HARB" ] || HARB=zig-out/bin/harb
T=zig-out/advisories_scene.tmp   # under the repository, so every path printed is the same on every run
rm -rf "$T"; mkdir -p "$T"
{
  for m in qemu_egress qemu_hello; do
    [ -f "zig-out/image/$m/kernel.sources" ] || { echo "no list of what $m's kernel compiled: run os2_image.sh $m first"; exit 1; }
  done
  run() { # a title, then the command; prints the title, the output and the exit code
    echo "=== $1"; shift
    "$@"; echo "exit $?"
  }
  run "qemu_egress: a network, so the IPv4 stack is compiled" "$HARB" advisories machines/qemu_egress.machine experiment/advisories --all
  run "qemu_hello: no network" "$HARB" advisories machines/qemu_hello.machine experiment/advisories --all
  run "by default, only what reaches and what cannot be told" "$HARB" advisories machines/qemu_egress.machine experiment/advisories
  run "one record, fixed: nothing reaches, exit 0" "$HARB" advisories machines/qemu_egress.machine experiment/advisories/CVE-0000-0002.json
  run "REFUSED: another machine's list" "$HARB" advisories machines/qemu_hello.machine experiment/advisories --sources zig-out/image/qemu_egress/kernel.sources
  sed '2s/^build [0-9.]*-/build 6.12.109-/' zig-out/image/qemu_egress/kernel.sources > "$T/old_pin.sources"
  run "REFUSED: a list of the kernel the pin held before" "$HARB" advisories machines/qemu_egress.machine experiment/advisories --sources "$T/old_pin.sources"
  mkdir -p "$T/records"; cp experiment/advisories/*.json "$T/records/"; echo "notes" > "$T/records/README"
  run "REFUSED: a directory that holds something that is not a record" "$HARB" advisories machines/qemu_egress.machine "$T/records"
  echo '{"id":"OSV-0000-0001","affected":[]}' > "$T/osv.json"
  run "REFUSED: a record that is not a CVE record" "$HARB" advisories machines/qemu_egress.machine "$T/osv.json"
  grep -v '^net/ipv4/tcp\.c$' zig-out/image/qemu_egress/kernel.sources > "$T/no_tcp.sources"
  run "the list decides: egress without net/ipv4/tcp.c" "$HARB" advisories machines/qemu_egress.machine experiment/advisories/CVE-0000-0001.json --sources "$T/no_tcp.sources" --all
} > "$LOG" 2>&1
[ $? = 0 ] || { cat "$LOG"; echo "SCENE: did not run"; exit 1; }
if diff -u "$PIN" "$LOG"; then
  echo "SCENE: matches $PIN ($(wc -l < "$LOG") lines)"
  exit 0
fi
echo "SCENE: DIFFERS from $PIN (above)"
exit 1
