#!/bin/bash
# os13_roll.sh -- who has written a record since (ROLL-1, STZ-OS-RULING-19).
#
# A fleet's machines keep signed records of their boots, and a fleet that names a time authority has the
# entries dated. `harb roll` reads what was BROUGHT -- a record and the statements beside it, one pair for each
# member that keeps a record -- against only what anybody holding the fleet file has, and says, for each member,
# whether the record is there, whether it is the member's own and whole, how far it goes and what the authority
# said of it; and, against the roll before, who has written since and by when, who has nothing new, and what the
# roll still holds of a record it could not read.
#
# The records here are REAL: this runs the time seat's arc (experiment/os10_time.sh -- an authority and a till on
# one wire, the till booted five times, the authority gone for two of them, then an impostor), and rolls over the
# two moments of the till's record that arc publishes (as it published it at its third boot, and at its fifth). What it
# adds is the roll:
#
#   A   the first roll, over the record as it stood: the till's entries, both dated; the clock box keeps none
#   B   two hours later, over the record as it stands, against A: two entries written since, the first of them
#       dated and the last not -- the authority had gone, and nothing dates what it did not hear
#   C   the same record again, against B: NOTHING NEW since B, and it says where the record ends
#   D   nobody brings the record, against B: ABSENT, and what B held of it -- what is lost is a line with numbers
#   D2  the record comes back, against D: NOTHING NEW since B. The roll that was not brought it did not lose it,
#       and the roll FILE shows why: it carries B's last entry and B's time
#   E   the record as it stood before B, against B: it is SHORTER than B saw. DIVERGED, and the roll keeps B's anchor
#   E2  the whole record, against E: the anchor was kept through the divergence, so this is NOTHING NEW since B
#   E3  the short record again, against E: DIVERGED again. It stays so until somebody says otherwise
#   E4  the short record, with no roll before: a first look, which is how a person accepts a record that went
#       backwards -- an act of the one who calls the roll, never a side effect of calling it; E5 goes on from it
#   F   an entry taken out of the middle, against B: BROKEN, inside what B vouched for
#   G   one second added to a statement, against B: the record is whole, and a statement does not verify
#   H   the record cut at its end with the authority's statements about the entries cut: statements about
#       entries it does not hold, and the record is shorter than B saw
#   I   the fleet before the till's key was enrolled: nobody can speak for its records
#   M   a roll shown a copy of the record OLDER than the authority's own date for an entry, and the next roll that
#       is shown the record as it stands: the authority dates the entry before the roll that did not have it, so
#       the copy that roll was shown was stale (or the clocks disagree), and that is a finding
#   O   the record brought with no statements beside it: ORDERED and UNDATED here
#   J   the roll as a file: written, read back, and the same call twice writes the same bytes
#   K   what is refused, in words: no fleet file, a time that is not one, a roll that is not there or is not a roll or is
#       another fleet's, a directory that is not there, and a roll as of a time earlier than the roll it is compared with
#
# THE CALLER'S CLOCK. The statements carry the emulator's times (a base the emulator is given, plus the seconds the
# virtual machine has run), which differ by a few seconds from one run to the next. A roll called at a moment the
# authority's own dates contradict is a FINDING -- and the scene asks for exactly one of those, in M -- so every
# roll here is called at a moment DERIVED from the statements: A just after the second statement, the stale one
# just after the third, and each of the others a fixed number of seconds after those. What is pinned of a time is
# therefore how long ago, which is a difference of constants, and never the time itself.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os13_roll.sh
#
# Log: zig-out/wsl/roll.txt; the judged text: machines/roll.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
T=zig-out/time
R=zig-out/roll
LOG=zig-out/wsl/roll.txt
mkdir -p zig-out/wsl
# THE LOG IS THIS RUN'S, ON EVERY PATH (RET-1)
rm -f "$LOG" zig-out/wsl/roll.body zig-out/wsl/roll.normalised zig-out/wsl/roll.diff

# one call of the verb: its words with the label before every line, and the exit code after them. The lines
# every call repeats (where the dates come from, the clock box that keeps nothing, the fleet's header) are said
# in full once, in A, and left out after it: they are the same words each time and would bury the ones that change
roll() { # $1 = label, then the arguments of `harb roll`
  local label=$1; shift
  "$H" roll "$@" 2>&1 | {
    if [ "${FULL:-0}" = 1 ]; then cat
    else grep -v -e '^roll: dates come from ' -e '^roll: clockbox -- keeps no record' -e '^roll: fleet nuage -- '
    fi
  } | sed "s/^/$label: /"
  echo "$label: exit ${PIPESTATUS[0]}"
}

# a roll file, its numbers named by the moments the scene called the rolls at (and the statements' times), so that
# what is pinned of a file is WHICH moment it holds and not the emulator's reading of it
show() { # $1 = label, $2 = a roll file
  awk -v known="A=$A_AT B=$B_AT C=$C_AT E4=$E4_AT M0=$M0_AT M=$M_AT BOUND2=$T2 BOUND3=$T3" -v label="$1" '
    BEGIN { n = split(known, kv, " "); for (i = 1; i <= n; i++) { split(kv[i], p, "="); name[p[2]] = p[1] } }
    {
      m = split($0, f, " "); line = ""
      for (i = 1; i <= m; i++) {
        w = f[i]; eq = index(w, "=")
        if (eq > 0) {
          key = substr(w, 1, eq - 1); val = substr(w, eq + 1)
          if ((key == "at" || key == "last" || key == "t") && (val in name)) w = key "=" name[val]
          else if (key == "head" && length(val) == 64) w = "head=H"
          else if (key == "authority" && length(val) == 16) w = "authority=FP"
        }
        line = (i == 1) ? w : line " " w
      }
      print "file: " label ": " line
    }' "$2"
}

(
  rm -rf "$R"; mkdir -p "$R"
  [ -x "$H" ] || { echo "no cross-built harb at $H -- zig build cross -j2"; exit 1; }

  echo "=== the arc the records come from: the time seat's, end to end ==="
  # the arc is judged by its own pin; the verdict is READ and not assumed (NAM-2)
  if ! bash experiment/os10_time.sh > /dev/null 2>&1; then
    echo "the time arc did not hold (zig-out/wsl/time.txt), so there is nothing to roll"; exit 1
  fi
  echo "arc: the time seat's arc matched its pin, and left the till's record at two moments, with the statements beside it"
  for f in declared3.record declared3.statements alone2.record alone2.statements removed.record cut.record changed.statements enrolled.fleet time_cloud.fleet time_clockbox.machine time_till.machine; do
    [ -s "$T/$f" ] || { echo "the arc left no $T/$f"; exit 1; }
  done
  F=$T/enrolled.fleet

  # the moments the rolls are called at: the time of the n-th statement of a file, as the authority stated it
  stated() { sed -n "${2}s/.* t=\\([0-9]*\\) .*/\\1/p" "$1"; }
  T2=$(stated "$T/declared3.statements" 2)   # entry 2 existed no later than this: what the first roll can hold
  T3=$(stated "$T/alone2.statements" 3)      # entry 3 existed no later than this: the first entry written after it
  if [ -z "$T2" ] || [ -z "$T3" ] || [ "$T3" -le "$T2" ]; then
    echo "the arc's statements are not in the order the scene needs (entry 2 at '$T2', entry 3 at '$T3')"; exit 1
  fi
  A_AT=$((T2 + 1))           # just after the record the first roll holds was dated, and before the next entry was
  B_AT=$((A_AT + 7500))      # 2 h 5 min after A
  C_AT=$((B_AT + 12900))     # 3 h 35 min after B
  AFTER_AT=$((C_AT + 5400))  # 1 h 30 min after C: D2, E2 and E3
  E4_AT=$((C_AT + 10800))    # 3 h after C
  E5_AT=$((E4_AT + 3600))
  M0_AT=$((T3 + 1))          # a roll called AFTER the authority dated entry 3, and shown the record without it
  M_AT=$((M0_AT + 7500))
  echo "clock: every roll is called at a moment derived from the statements' own times; what is pinned is how long ago"

  # what a collector brings, for the member that keeps a record: the record as the machine holds it, and the
  # statements beside it, named for the member
  mkdir -p "$R/early" "$R/late" "$R/nothing" "$R/removed" "$R/changed" "$R/cut" "$R/bare"
  cp "$T/declared3.record"     "$R/early/till.record";   cp "$T/declared3.statements" "$R/early/till.record.time"
  cp "$T/alone2.record"        "$R/late/till.record";    cp "$T/alone2.statements"    "$R/late/till.record.time"
  cp "$T/removed.record"       "$R/removed/till.record"; cp "$T/alone2.statements"    "$R/removed/till.record.time"
  cp "$T/alone2.record"        "$R/changed/till.record"; cp "$T/changed.statements"   "$R/changed/till.record.time"
  cp "$T/cut.record"           "$R/cut/till.record";     cp "$T/alone2.statements"    "$R/cut/till.record.time"
  cp "$T/alone2.record"        "$R/bare/till.record"

  echo "=== A: the first roll, over the record the till published at its third boot ==="
  FULL=1 roll A "$F" "$R/early" --at "$A_AT" --out "$R/a.roll"

  echo "=== B: two hours later, over the record it published at its fifth boot, against A ==="
  roll B "$F" "$R/late" --since "$R/a.roll" --at "$B_AT" --out "$R/b.roll"

  echo "=== C: the same record again, against B ==="
  roll C "$F" "$R/late" --since "$R/b.roll" --at "$C_AT"

  echo "=== D: nobody brings the record, against B ==="
  roll D "$F" "$R/nothing" --since "$R/b.roll" --at "$C_AT" --out "$R/d.roll"

  echo "=== D2: the record comes back, against D ==="
  roll D2 "$F" "$R/late" --since "$R/d.roll" --at "$AFTER_AT"

  echo "=== E: the record as it stood before B, against B: shorter than B saw ==="
  roll E "$F" "$R/early" --since "$R/b.roll" --at "$C_AT" --out "$R/e.roll"

  echo "=== E2: the whole record, against E ==="
  roll E2 "$F" "$R/late" --since "$R/e.roll" --at "$AFTER_AT"

  echo "=== E3: the short record again, against E ==="
  roll E3 "$F" "$R/early" --since "$R/e.roll" --at "$AFTER_AT"

  echo "=== E4: the short record, with no roll before it ==="
  roll E4 "$F" "$R/early" --at "$E4_AT" --out "$R/e4.roll"

  echo "=== E5: the short record, against E4 ==="
  roll E5 "$F" "$R/early" --since "$R/e4.roll" --at "$E5_AT"

  echo "=== F: an entry taken out of the middle of the record, against B ==="
  roll F "$F" "$R/removed" --since "$R/b.roll" --at "$C_AT"

  echo "=== G: one second added to a statement, against B ==="
  roll G "$F" "$R/changed" --since "$R/b.roll" --at "$C_AT"

  echo "=== H: the record cut at its end, with the authority's statements about what was cut, against B ==="
  roll H "$F" "$R/cut" --since "$R/b.roll" --at "$C_AT"

  echo "=== I: the fleet before the till's key was enrolled ==="
  roll I "$T/time_cloud.fleet" "$R/late" --at "$C_AT"

  echo "=== M: a roll shown a record older than the authority's own date for an entry ==="
  roll M0 "$F" "$R/early" --at "$M0_AT" --out "$R/m0.roll"
  roll M "$F" "$R/late" --since "$R/m0.roll" --at "$M_AT"

  echo "=== O: the record brought with no statements beside it, against B ==="
  roll O "$F" "$R/bare" --since "$R/b.roll" --at "$C_AT"

  echo "=== J: the roll is a file, and the same call twice writes the same bytes ==="
  roll J "$F" "$R/late" --since "$R/a.roll" --at "$B_AT" --out "$R/j.roll" > /dev/null
  if cmp -s "$R/b.roll" "$R/j.roll"; then echo "file: B and J are the same $(wc -c < "$R/b.roll") bytes"; else echo "file: B and J DIFFER"; fi
  show A "$R/a.roll"
  show B "$R/b.roll"
  show D "$R/d.roll"
  show E "$R/e.roll"
  show E4 "$R/e4.roll"

  echo "=== K: what is refused, in words ==="
  roll K1 "$F"
  roll K2 "$F" "$R/late" --at yesterday
  roll K3 "$F" "$R/late" --since "$R/none.roll"
  printf 'not a roll\n' > "$R/junk.roll"
  roll K4 "$F" "$R/late" --since "$R/junk.roll"
  printf 'roll v1 fleet=elsewhere at=5 authority=-\nend\n' > "$R/other.roll"
  roll K5 "$F" "$R/late" --since "$R/other.roll"
  roll K6 "$F" "$R/nowhere"
  # a roll as of a time earlier than the roll it is compared with, over a member nobody brought: the anchor it would
  # carry is later than the roll that carries it, so the file would not read back, and nothing is written
  roll K7 "$F" "$R/nothing" --since "$R/b.roll" --at "$A_AT" --out "$R/k7.roll"
  if [ -e "$R/k7.roll" ]; then echo "file: K7 wrote a roll"; else echo "file: K7 wrote no roll"; fi
) > zig-out/wsl/roll.body 2>&1
SCENE=$?

# The key, the fingerprint, the hash and the time are made on the device or by its clock and differ in every
# build. Each DISTINCT fingerprint becomes FP1, FP2, ... in order of first appearance, so what survives is the
# claim that matters: the same device twice reads as FP2 twice, and a device that CHANGED would read as FP3 and
# convict. Every absolute time a sentence prints is the emulator's, or a constant derived from it, and is marked;
# how long ago is a difference of constants and stays, so that "2 h 5 min before this one" is pinned (FLT-1, IDN-1).
sed -e 's/\r$//' \
    -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@F@\1@@F@/g' \
    -e 's/head [0-9a-f]\{8\}/head H8/g' \
    -e 's/ending in [0-9a-f]\{8\}/ending in H8/g' \
    -e 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}\(:[0-9]\{2\}\)\{0,1\} UTC/<time>/g' zig-out/wsl/roll.body \
  | awk '
      {
        while (match($0, /@@F@[0-9a-f]+@@F@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8)
          if (!(v in F)) { nf++; F[v] = "FP" nf }
          $0 = substr($0, 1, RSTART - 1) F[v] substr($0, RSTART + RLENGTH)
        }
        print
      }' > zig-out/wsl/roll.normalised

{
  cat zig-out/wsl/roll.body
  echo "=== judge ==="
  VERDICT=0
  if [ "$SCENE" != 0 ]; then
    echo "JUDGED: FAIL -- the scene stopped before it was done (exit $SCENE); what it said is above"
    VERDICT=1
  elif [ ! -f machines/roll.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/roll.normalised"
  elif diff -u machines/roll.expected zig-out/wsl/roll.normalised > zig-out/wsl/roll.diff; then
    echo "JUDGED: the roll matches machines/roll.expected line for line ($(wc -l < zig-out/wsl/roll.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the roll differs from machines/roll.expected:"; cat zig-out/wsl/roll.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's (VDCT-1)
exit "${PIPESTATUS[0]}"
