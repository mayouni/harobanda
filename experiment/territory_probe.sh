#!/bin/bash
# territory_probe.sh -- a law about where the data stays is a line the court reads, and every rule that says so is convicted when it is broken (TERR-1).
#
# The territory seat is `TERRITORY` on a fleet member and `RESIDENCY` on the fleet (src/fleet.zig), the two
# kinds the machine grammar refuses in a machine file (src/machine.zig), and the roll that names the law and
# whom it binds (src/main.zig). It boots nothing: it is judged by the fleet court and the machine court, by
# fixtures. A guard that has never been seen to convict is a claim, and a court that never convicts is as
# useless as one that always does (VDCT-1). So this builds the three courts from the production source, then
# runs each rule against a scratch copy of the source with ONE mutation each, and requires every mutant to be
# convicted by the fixture named for the rule it breaks (a refusal that is computed and not returned, a
# condition dropped, a name taken off a list). A mutant that makes the court CRASH on the case is convicted
# too, and the probe says so: it is the case that reached the code.
#
#   what a member keeps data on   the filesystems that survive the power, and the read-only exemption
#   the law                       a member with no territory, a member in another, a law that binds nobody,
#                                 two laws, the residency's own territory, the member's
#   the machine grammar           a RESIDENCY in a machine file, a TERRITORY on a machine
#
# The first run of this probe on the first version of the fixtures found two holes: no fixture kept data on
# a FAT partition, and none on an edge machine's flash, so taking `vfat` or `littlefs` off the list of
# filesystems that survive the power was convicted by nothing. FR72 and FR73 are what it asked for.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/territory_probe.sh
#
# Log: zig-out/wsl/territory_probe.txt, this run's or absent. Exit 0 only if the production source passes its
# three courts and every mutant is convicted by the case named for it. It builds a copy of the sources under
# $HOME and never touches this repository's tree.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-territory-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/territory_probe.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'fn checkResidency' src/fleet.zig || { echo "src/fleet.zig has no checkResidency: nothing to probe"; exit 1; }
  verdict=0
  MC=src/machine.zig; FL=src/fleet.zig

  echo "=== the production source: the three courts, built and run on Linux ==="
  if ! "$Z" build -j2 > "$S/build.txt" 2>&1; then echo "THE PRODUCTION SOURCE DOES NOT BUILD"; grep -m5 'error:' "$S/build.txt"; echo "exit 1"; exit 1; fi
  for c in "court" "court --fleet" "court --pack"; do
    # shellcheck disable=SC2086 -- the word split is the argument list
    ./zig-out/bin/harb $c > "$S/production_court.txt" 2>&1
    RC=$?
    echo "--- harb $c: exit $RC -- $(tail -1 "$S/production_court.txt")"
    if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN COURT ($c)"; verdict=1; fi
  done

  # one mutation of a grammar's rules: $1 = label, $2 = the file, $3 = the sed program, $4 = machine|fleet,
  # $5 = the case that must convict it. The mutant must differ, compile, and fail THAT case -- by its FAIL line,
  # or by a crash while it was being judged (the case never reached an ok line)
  cmutant() {
    echo "=== $1 ==="
    cp "$2" "$2.orig"
    sed -i "$3" "$2"
    if cmp -s "$2" "$2.orig"; then echo "the mutation did not apply"; verdict=1; cp "$2.orig" "$2"; rm -f "$2.orig"; return; fi
    if ! "$Z" build -j2 > "$S/build.txt" 2>&1; then
      echo "MUTANT DID NOT COMPILE ($1): that convicts nothing"; grep -m3 'error:' "$S/build.txt"; verdict=1
    else
      if [ "$4" = fleet ]; then ./zig-out/bin/harb court --fleet > "$S/court.txt" 2>&1; else ./zig-out/bin/harb court > "$S/court.txt" 2>&1; fi
      RC=$?
      if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($1)"; verdict=1
      elif grep -q "FAIL $5 " "$S/court.txt"; then echo "convicted by $5"
      elif grep -qi 'panic' "$S/court.txt" && ! grep -q "ok   $5 " "$S/court.txt"; then echo "convicted by a crash while judging $5"
      else echo "MUTANT NOT CONVICTED BY ITS CASE ($1: wanted $5)"; grep -m3 'FAIL' "$S/court.txt"; verdict=1; fi
    fi
    cp "$2.orig" "$2"; rm -f "$2.orig"
  }
  # a refusal that is computed and not returned: the rule is read, and obeyed by nobody (Zig refuses to
  # discard an error set, so the refusal is turned into the number it is and thrown away as that)
  NR='s/return ctx\.refuse(\(.*\));/_ = @intFromError(ctx.refuse(\1));/'

  # what a member keeps data on
  cmutant "c1: a volatile disk is data" $FL 's/\.ext4, \.vfat, \.littlefs => {},/.ext4, .vfat, .littlefs, .tmpfs => {},/' fleet FA16
  cmutant "c2: a read-only disk is data" $FL 's/if (o == \.ro) read_only = true;/if (o == .ro) read_only = false;/' fleet FA16
  cmutant "c3: a FAT partition keeps nothing" $FL 's/\.ext4, \.vfat, \.littlefs => {},/.ext4, .littlefs => {},/' fleet FR72
  cmutant "c4: an edge machine's flash keeps nothing" $FL 's/\.ext4, \.vfat, \.littlefs => {},/.ext4, .vfat => {},/' fleet FR73
  # the law
  cmutant "c5: a member that keeps a disk and says nowhere is excused" $FL '/says no TERRITORY, so nobody can check/s/const where = m\.territory orelse return ctx\.refuse(.*$/const where = m.territory orelse continue;/' fleet FR69
  cmutant "c6: a member in another territory is accepted" $FL 's/if (!std\.mem\.eql(u8, where, r\.territory)) return ctx\.refuse(/if (false and !std.mem.eql(u8, where, r.territory)) return ctx.refuse(/' fleet FR70
  cmutant "c7: a law that binds nobody is kept" $FL 's/if (bound == 0) return ctx\.refuse(/if (false and bound == 0) return ctx.refuse(/' fleet FR68
  cmutant "c8: nobody is bound by the law" $FL 's/bound += 1;/bound += 0;/' fleet FA14
  cmutant "c9: two laws are one fleet's" $FL "/says where the data stays, and {s} already does/$NR" fleet FR67
  cmutant "c10: the residency's territory is cut short" $FL 's/\.territory = try machine\.wantIdent(&ctx, tc), \.rationale/.territory = (try machine.wantIdent(\&ctx, tc))[0..1], .rationale/' fleet FA14
  cmutant "c11: a member's territory is read as nothing" $FL 's/if (machine\.find(d, "TERRITORY")) |c| territory = try machine\.wantIdent(&ctx, c);/if (machine.find(d, "TERRITORY")) |c| territory = (try machine.wantIdent(\&ctx, c))[0..0];/' fleet FA14
  cmutant "c12: a member takes no territory" $MC 's/"HARDWARE", "TERRITORY" }/"HARDWARE" }/' fleet FA14
  # the machine grammar
  cmutant "c13: a machine says where it stands" $MC 's/"TIME_KEY", "CORES" }/"TIME_KEY", "CORES", "TERRITORY" }/' machine R209
  cmutant "c14: a residency in a machine file" $MC 's/\.FLEET, \.MEMBER, \.RETIREMENT, \.ROUTE, \.FRONT, \.RESIDENCY => true,/.FLEET, .MEMBER, .RETIREMENT, .ROUTE, .FRONT => true, .RESIDENCY => false,/' machine R208

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production source passes its three courts, and every mutant that was run is convicted by the case named for its rule"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
