#!/bin/bash
# time_probe.sh -- time enters a record only as a statement somebody signed, and every rule that says so is convicted when it is broken (TIME-1).
#
# The time seat (STZ-OS-RULING-07) is a statement and its judgement (src/timeattest.zig), the reading that dates a
# record with it (src/timeaudit.zig), the acts that touch a kernel (src/timeserve.zig), and the rules of two
# grammars that say who may state a time and who may take one (src/machine.zig, src/fleet.zig). A guard that has
# never been seen to convict is a claim, and a court that never convicts is as useless as one that always does
# (VDCT-1). So this runs each of them against scratch copies of the source with ONE mutation each, and requires
# every mutant to be convicted -- by the test, or the fixture, named for the rule it breaks:
#
#   units    the tests, on Linux (the wire test needs a kernel), then 31 mutants of the four modules:
#              the signature not checked / the authority not checked / a statement that is not exactly its
#              fields / an uppercase spelling taken for the same bytes / an entry that is not hex / a bound rounded
#              the wrong way / a wrong calendar / an entry dated only by its own statement / the first statement
#              taken for the earliest / a statement about an entry the record does not hold not refused / a chain
#              not checked / a hash not checked / a refused statement counted clean / an export's own word not
#              stripped / an empty record accepted / an answer about another entry taken / an answer whose
#              signature is not checked / any reading taken for a time / any datagram answered / a clock that
#              failed answered with a made-up time / a statement run onto a line the power cut short / a responder
#              that keeps what PID 1 held / a time spelled with a leading zero / any number of line ends after a
#              statement / an entry named by a hash anybody can compute in advance / a signature over other bytes
#              taken for an entry / a time signed or taken from before the clock was set / a clock that went
#              backwards not counted, or noticed in one order of the file only
#   courts   the machine, fleet and pack courts, then 33 mutants of the machine grammar's time rules and 11 of
#              the fleet's, each convicted by the fixture named for its rule (a refusal that is computed and not
#              returned, a condition dropped, a bound moved). A mutant that makes the court CRASH on the case is
#              convicted too, and the probe says so: it is the case that reached the code
#   all      both (the default)
#
# The first run of this probe on the first version of the fixtures found two holes: no fixture judged a port
# boundary, and none a device path that starts under /dev and climbs out of it. A38-A40 and R159-R162 are what it
# asked for. What it does not reach: PID 1's acts (the answer is kept only when it is the authority's word) are
# judged by experiment/os10_time.sh, which boots them; and a datagram from somewhere else than the authority's
# address is stopped by the asker's connected socket AND by the signature, and only the second is judged here.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/time_probe.sh [units|courts|all]
#
# Log: zig-out/wsl/time_probe_<mode>.txt, this run's or absent. Exit 0 only if the production source passes
# (and its tests RAN, not skipped) and every mutant is convicted by the case named for it. It builds a copy of the
# sources under $HOME and never touches this repository's tree; it boots nothing.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
MODE=${1:-all}
case "$MODE" in units|courts|all) ;; *) echo "usage: time_probe.sh [units|courts|all]"; exit 2 ;; esac
S=$HOME/harb-time-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/time_probe_$MODE.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'pub fn respond' src/timeserve.zig || { echo "src/timeserve.zig has no respond: nothing to probe"; exit 1; }
  verdict=0

  # ---- the tests ------------------------------------------------------------------------------------
  utest() { # $1 = label ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test src/main.zig --test-filter "TIME-1" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|TIME-1' "$S/$1.txt" | head -8
  }

  # one mutation: $1 = label, $2 = the file, $3 = the sed program, $4 = a fragment of the name of the test that
  # must convict it. The mutant must differ from the source, fail, compile, and be convicted by THAT test (its
  # status line is not OK) -- not merely by something that stopped compiling.
  umutant() {
    echo "=== $1 ==="
    cp "$2" "$2.orig"
    sed -i "$3" "$2"
    if cmp -s "$2" "$2.orig"; then echo "the mutation did not apply"; verdict=1; fi
    utest mutant
    if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($1)"; verdict=1; fi
    if grep -q 'error:' "$S/mutant.txt" && ! grep -qF "$4" "$S/mutant.txt"; then
      echo "MUTANT DID NOT COMPILE ($1): that convicts nothing"; grep -m3 'error:' "$S/mutant.txt"; verdict=1
    fi
    # the test's name and a failure's message share the line the runner prints, and its FAIL is on the next one,
    # so the name is what is asked for: convicted means the line of THAT test does not end in OK
    grep -F "$4" "$S/mutant.txt" | grep -vq '\.\.\.OK$' || { echo "MUTANT NOT CONVICTED BY ITS TEST ($1)"; verdict=1; }
    cp "$2.orig" "$2"; rm -f "$2.orig"
  }

  if [ "$MODE" = units ] || [ "$MODE" = all ]; then
    echo "=== the production source, on Linux (uid $(id -u)) ==="
    utest production
    if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS"; verdict=1; fi
    # the tests must have RUN, not been skipped: a skip is no witness
    if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the question was not asked"; verdict=1; fi
    grep -F "asked over a wire" "$S/production.txt" | grep -q '\.\.\.OK$' || { echo "the wire test did not run and pass"; verdict=1; }

    AT=src/timeattest.zig; AU=src/timeaudit.zig; SV=src/timeserve.zig; JR=src/journal.zig
    umutant "u1: the signature is not checked" $AT 's/\.verify(body, public) catch return \.bad_signature;/.verify(body, public) catch {};/' "is refused for its own reason"
    umutant "u2: the authority is not checked" $AT 's/if (!std\.mem\.eql(u8, &fp, &st\.authority)) return \.wrong_authority;/if (false and !std.mem.eql(u8, \&fp, \&st.authority)) return .wrong_authority;/' "is refused for its own reason"
    umutant "u3: something may follow the signature" $AT '/if (it\.next() != null) return null;/d' "is refused for its own reason"
    umutant "u4: an uppercase spelling is taken for the same bytes" $AT 's/if (!std\.ascii\.isHex(c) or std\.ascii\.isUpper(c)) return false;/if (!std.ascii.isHex(c)) return false;/' "is refused for its own reason"
    umutant "u5: an entry need not be hex" $AT '/^pub fn parseRequest/,/^}/s/ or !isHex(entry)//' "are one datagram each"
    umutant "u6: a bound is rounded down" $AT 's/@divFloor(t + 59, 60)/@divFloor(t, 60)/' "rounded UP to the minute"
    umutant "u7: the calendar is a month out" $AT 's/mp + 3 else mp - 9/mp + 2 else mp - 9/' "the calendar is exact"
    umutant "u8: an entry is dated only by its own statement" $AU 's/for (0\.\.idx + 1) |i| {/for (idx..idx + 1) |i| {/' "bounded by the earliest statement"
    umutant "u9: the first statement read is taken for the earliest" $AU 's/if (bound\[i\] == null or st\.t < bound\[i\]\.?) {/if (bound[i] == null) {/' "bounded by the earliest statement"
    umutant "u10: a statement about another chain is not refused" $AU '/entries were cut from the end of this one/{n;d}' "cannot be taken is refused"
    umutant "u11: a record's chain is not checked" $AU 's/if (!std\.mem\.eql(u8, pfield, expect_prev)) {/if (false and !std.mem.eql(u8, pfield, expect_prev)) {/' "agrees with the journal"
    umutant "u12: an entry's hash is not checked" $AU 's/if (!std\.mem\.eql(u8, hash_text, &want)) {/if (false and !std.mem.eql(u8, hash_text, \&want)) {/' "agrees with the journal"
    umutant "u13: a refused statement counts as clean" $AU 's/r\.refused += 1;/r.refused += 0;/' "cannot be taken is refused"
    umutant "u14: an export's own word is not stripped" $AU 's/bare(raw, "statement ")/bare(raw, "stmt ")/' "cannot be taken is refused"
    umutant "u15: an empty record is a record" $AU 's/if (es\.len == 0) {/if (false) {/' "cannot be taken is refused"
    umutant "u16: an answer about another entry is taken" $SV 's/if (!std\.mem\.eql(u8, &st\.entry, entry)) {/if (false and !std.mem.eql(u8, \&st.entry, entry)) {/' "asked over a wire"
    # (the key stays used, or an unused parameter is a compile error and the mutant convicts nothing)
    umutant "u17: an answer's signature is not checked" $SV 's/switch (timeattest\.verify(datagram, key)) {/switch (@as(timeattest.Verdict, if (timeattest.parse(datagram) != null and key.bytes.len > 0) .ok else .malformed)) {/' "asked over a wire"
    # (t stays used: an unused parameter is a compile error, which convicts nothing)
    umutant "u18: any reading is a time" $SV 's/return t >= earliest;/return t >= earliest or t < earliest;/' "can be this decade"
    umutant "u19: any datagram is answered" $SV 's/const entry = timeattest\.parseRequest(datagram) orelse return null;/const entry = timeattest.parseRequest(datagram) orelse ([_]u8{48} ** 64);/' "signed statement, or nothing at all"
    # (a made-up time that `sign` would take: zero is refused there, which would make the mutant no mutant)
    umutant "u20: a clock that failed is answered with a made-up time" $SV 's/const t = readRtc(clock) catch return null;/const t = readRtc(clock) catch timeattest.earliest;/' "will not answer makes silence"
    umutant "u21: a statement is run onto a line the power cut short" $SV 's/if ((try f\.preadAll(&last, end - 1)) == 1 and last\[0\] != /if (false and (try f.preadAll(\&last, end - 1)) == 1 and last[0] != /' "a line of its own"
    # the guards the independent review of the seat asked for: each is a mutant that was green until its case existed
    umutant "u22: the responder keeps what PID 1 held" $SV 's/if (fd != except) _ = linux\.close(fd);/if (fd != except and false) _ = linux.close(fd);/' "keeps nothing of PID 1"
    umutant "u23: a time may be spelled with a leading zero" $AT 's/if (s\.len > 1 and s\[0\] == \x270\x27) return null;//' "is refused for its own reason"
    umutant "u24: any number of line ends follow a statement" $AT 's/var l = line;/var l = std.mem.trimRight(u8, line, "\\r\\n");/' "is refused for its own reason"
    umutant "u25: an entry is named by its public hash, which anybody can compute in advance" $AT 's/Sha256\.hash(trimTerminator(line), &d, \.{});/Sha256.hash(line[0 .. std.mem.indexOf(u8, line, " hash=") orelse line.len], \&d, .{});/' "named by its whole signed line"
    umutant "u26: a signature over other bytes is an entry" $JR 's/return std\.mem\.startsWith(u8, payload, want);/return std.mem.startsWith(u8, payload, want) or true;/' "is not a journal entry"
    umutant "u27: the authority signs a time before its clock was set" $AT 's/if (t < earliest or t > max_t) return error\.NotATime;//' "is refused for its own reason"
    umutant "u28: the auditor takes a time before the clock was set" $AT 's/if (st\.t < earliest) return \.implausible;//' "is refused for its own reason"
    # the second review: a later entry dated earlier is said, whichever of the two the file keeps first
    umutant "u29: a clock that went backwards is not counted" $AU 's/r\.backwards += 1;/r.backwards += 0;/' "bounded by the earliest statement"
    umutant "u30: a later entry dated earlier is noticed only when the earlier entry's statement comes first" $AU 's/const earlier_later = p\.idx > idx and p\.t < st\.t;/const earlier_later = false and p.idx > idx and p.t < st.t;/' "bounded by the earliest statement"
    umutant "u31: a later entry dated earlier is noticed only when the later entry's statement comes first" $AU 's/const later_earlier = p\.idx < idx and p\.t > st\.t;/const later_earlier = false and p.idx < idx and p.t > st.t;/' "bounded by the earliest statement"
  fi

  # ---- the courts -----------------------------------------------------------------------------------
  if [ "$MODE" = courts ] || [ "$MODE" = all ]; then
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

    cmutant "c1: a clock on an edge machine" $MC "/CLOCK is a hosted machine/$NR" machine R139
    cmutant "c2: a clock at any path" $MC "/CLOCK is the device path of the clock this machine has/$NR" machine R140
    cmutant "c3: a device path need not be plain" $MC 's|!plainPath(path) or ||' machine R159
    cmutant "c4: /dev itself is a clock" $MC 's| or path\.len <= "/dev/"\.len||' machine R142
    cmutant "c5: a clock need not be a device" $MC 's| or !within(path, "/dev")||' machine R140
    cmutant "c6: a clock with no key to sign with" $MC "/a clock is read to SIGN/$NR" machine R143
    cmutant "c7: a clock that attests nothing" $MC "/CLOCK is the clock a time authority reads/$NR" machine R144
    cmutant "c8: an authority with no clock" $MC "/declares no CLOCK/$NR" machine R145
    cmutant "c9: an authority on a leased address" $MC "/is not a lease: a time authority declares a static/$NR" machine R146
    cmutant "c10: a port below 1024" $MC 's/if (port < 1024 or port > 65535)/if (port > 65535)/' machine R147
    cmutant "c11: a port above 65535" $MC 's/if (port < 1024 or port > 65535)/if (port < 1024)/' machine R161
    cmutant "c12: an authority on two links" $MC "/a machine answers the time on one link/$NR" machine R148
    cmutant "c13: an authority on a loopback" $MC "/which nobody else can ask: a time authority answers on a link/$NR" machine R149
    cmutant "c14: an authority that asks" $MC "/this machine is a time authority and asks for the time of its own record/$NR" machine R150
    cmutant "c15: an authority to ask with no key to take its word by" $MC '/TIME_FROM names whom this machine asks/s/const tk = tk_c orelse return ctx\.refuse(.*$/const tk = tk_c orelse tf;/' machine R151
    cmutant "c16: a key with nobody to ask" $MC '/TIME_KEY is whose word this machine takes/s/const tf = tf_c orelse return ctx\.refuse(.*$/const tf = tf_c orelse tk_c.?;/' machine R152
    cmutant "c17: an authority that is not an address and a port" $MC '/TIME_FROM is the authority/s/parseHostPort(text) orelse return ctx\.refuse(.*$/parseHostPort(text) orelse parseHostPort("10.30.0.1:7000").?;/' machine R153
    cmutant "c18: port 0 is a port" $MC '/^pub fn parseHostPort/,/^}/{/if (port == 0) return null;/d}' machine R154
    cmutant "c19: a number that does not fit a port is wrapped into one" $MC 's/const port = std\.fmt\.parseInt(u16, text\[colon + 1 \.\.\], 10) catch return null;/const port: u16 = @truncate(std.fmt.parseInt(u32, text[colon + 1 ..], 10) catch return null);/' machine R162
    cmutant "c20: a key in any spelling" $MC 's/if (key_text\.len != 64 or !lowerHex(key_text))/if (key_text.len != 64)/' machine R155
    cmutant "c24: a key no public key is written as" $MC 's/\(PublicKey\.fromBytes(key) catch\) return ctx\.refuse(.*$/\1 {};/' machine R163
    # the rules the independent review of the seat asked for
    cmutant "c25: a clock is any device" $MC 's/if (!isRtcNode(path)) return ctx\.refuse(/if (false and !isRtcNode(path)) return ctx.refuse(/' machine R164
    cmutant "c26: a device that asks the time on an edge machine" $MC "/TIME_FROM is a hosted machine/$NR" machine R165
    cmutant "c27: a port may be spelled with a leading zero" $MC '/if (!plainDecimal(text\[colon + 1 \.\.\])) return null;/d' machine R166
    # (the loop and the capture stay used: an unused variable is a compile error, which convicts nothing)
    cmutant "c28: an address may be spelled with a leading zero" $MC 's/while (octets\.next()) |o| if (!plainDecimal(o)) return null;/while (octets.next()) |o| if (!plainDecimal(o) and false) return null;/' machine R167
    cmutant "c29: an address off every link is on one" $MC 's/if (onPrefix(s\.ip, s\.prefix, ip)) return true;/if (onPrefix(s.ip, s.prefix, ip) or true) return true;/' machine R168
    cmutant "c30: a link with no gateway has a default route" $MC 's/\.unrestricted => if (n\.gateway != null) return true,/.unrestricted => return true,/' machine R168
    cmutant "c31: an EGRESS list reaches what it does not name" $MC 's/for (dests) |d| if (onPrefix(d\.ip, d\.prefix, ip)) return true;/for (dests) |d| if (onPrefix(d.ip, d.prefix, ip) or true) return true;/' machine R169
    # a route to another network is written THROUGH a gateway, and with none declared none is written at all
    cmutant "c33: an EGRESS list is a way with no gateway to carry the question" $MC 's/\.to => |dests| if (n\.gateway != null) {/.to => |dests| if (n.gateway != null or true) {/' machine R170
    cmutant "c32: a lease is no way there" $MC 's/\.dhcp => return true,/.dhcp => {},/' machine A43
    cmutant "c21: a time asked of a machine with no record" $MC "/declares no JOURNAL: there is nothing/$NR" machine R156
    cmutant "c22: a time asked over no network" $MC "/TIME_FROM asks over a network/$NR" machine R157
    cmutant "c23: TIME_AUTHORITY on a machine" $MC 's/"CLOCK", "TIME_FROM", "TIME_KEY" }/"CLOCK", "TIME_FROM", "TIME_KEY", "TIME_AUTHORITY" }/' machine R158

    cmutant "f1: an authority nobody declared" $FL '/TIME_AUTHORITY names {s}, and no MEMBER/s/const am = f\.member(who) orelse return ctx\.refuse(.*$/const am = f.member(who) orelse return;/' fleet FR50
    cmutant "f2: an authority nobody can check" $FL "/has no KEY: a statement nobody can check/$NR" fleet FR51
    cmutant "f3: an authority that cannot answer" $FL '/its machine declares no NETWORK with TIME_AUTHORITY/s/const wire = net orelse return ctx\.refuse(.*$/const wire = net orelse return;/' fleet FR52
    cmutant "f4: a member answers the time and the fleet never named it" $FL "/answers the time, and this fleet declares no TIME_AUTHORITY/$NR" fleet FR53
    cmutant "f5: two authorities" $FL "/answers the time too, and/$NR" fleet FR54
    cmutant "f6: a question nobody was declared to answer" $FL "/this fleet declares no time authority/$NR" fleet FR55
    cmutant "f7: it asks somebody at another address" $FL 's/if (tf\.ip != at\.ip or tf\.port != wire\.time_authority\.?) {/if (tf.port != wire.time_authority.?) {/' fleet FR56
    cmutant "f8: it asks somebody on another port" $FL 's/if (tf\.ip != at\.ip or tf\.port != wire\.time_authority\.?) {/if (tf.ip != at.ip) {/' fleet FR57
    cmutant "f9: it takes the word of another key" $FL "/the word it takes is not the authority/$NR" fleet FR58
    cmutant "f10: a question with no way there" $FL "/a question with no way there/$NR" fleet FR59
    cmutant "f11: any link is a way there" $FL 's/ or f\.joined(n\.name, wire\.name)/ or true/' fleet FR59
  fi

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    case "$MODE" in
      units)  WHAT="its tests, none skipped" ;;
      courts) WHAT="its three courts" ;;
      *)      WHAT="its tests, none skipped, and its three courts" ;;
    esac
    echo "PROBED ($MODE): the production source passes $WHAT, and every mutant that was run is convicted by the case named for its rule"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
