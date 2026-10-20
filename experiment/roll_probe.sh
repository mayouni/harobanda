#!/bin/bash
# roll_probe.sh -- a roll is the records' word, and every rule that says so is convicted when it is broken (ROLL-1).
#
# The roll call (STZ-OS-RULING-19) is one module that needs no kernel, src/roll.zig: it reads what members brought
# against the fleet's keys and the time authority's, and against the roll before. A guard that has never been seen
# to convict is a claim (VDCT-1), so this runs the module's tests, then each of its rules against a scratch copy of
# the source with ONE mutation, and requires every mutant to be convicted -- by the test named for the rule:
#
#   the file       a number with a leading zero / a name in capitals or longer than a name may be / a hash in
#                    capitals / a member twice / a line after `end` / a head with no entry behind it, an anchor with no
#                    roll that held it, one held in the future, a held member held by another roll, a divergence from
#                    nothing, entries dated and no time to say it by, or a date past the end / a fingerprint of any
#                    length / a time later than a statement may state
#   the time       a date the calendar has not taken for one / a sign in a date
#   the reading    a statement dating only the entry it names / the LATEST bound taken for the best / a statement
#                    nobody verified taken / a statement about no entry here or one that does not verify taken without
#                    a word / the anchor made of a line without its signature, which two devices of one design share /
#                    the newest dated entry the first / the newest bound the first / a retired key not heard / an
#                    unenrolled member, an absent one, an empty one or one no key signed told for another
#   the comparison a record shorter than the roll saw taken for the roll's / the anchor not looked for / a record that
#                    has not grown told from one that has / the first new entry's bound read from the wrong place /
#                    the undated counted the wrong way / a member nobody brought told from one that was never there /
#                    a break after what the roll vouched for told from a break inside it / a roll that could not vouch
#                    for a member compared with all the same / a record nobody can vouch for placed against the roll /
#                    a member the roll did not have called old / a machine that no longer keeps a record forgotten /
#                    an authority's date before the roll that did not have the entry, taken without a word, or read the
#                    wrong way round
#   what is kept   a record that went backwards adopted as the anchor / the anchor not carried across a roll that could
#                    not hold the member (its entries, the time of the roll that held it) / a diverged record not said
#                    to be / an adopted observation stamped with a time that is not its roll's / the roll writing what it saw and not
#                    what it holds
#   the verdict    a roll that is not clean said to be: an absent member / a diverged one / a forked one / one that does
#                    not verify, is nobody's, is empty or is not enrolled / a statement that did not verify / one that
#                    is about no entry here / a stale copy / a machine that stopped declaring a record / a fleet that
#                    keeps no record
#   the words      a member that left the fleet / the count of those / a clock that reads before the roll it is compared
#                    with / another authority's roll / a roll of another fleet / the span of a roll in hours / a plural /
#                    the date of the caller's clock / a bound and a roll set side by side to the second / a record
#                    brought for a machine that keeps none
#
# What it does not reach, and says: the sentence a finding is worded in is judged by the substring a test looks for,
# so a rewording that keeps the substring is not a bug; `--out` is written whole by writing a file beside it and
# renaming it, and a test cannot make a disk fail half way, so that is by construction and unprobed; and the records'
# own judgement (a chain, a signature, a retirement) is the fleet's and the journal's, probed beside them
# (experiment/time_probe.sh) -- the roll asks them and mutates nothing of them. The scene (experiment/os13_roll.sh) runs
# the verb over a real arc.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/roll_probe.sh [r14 r48 ...]
#
# Name some mutants (r1 .. r89) to run only those: the log says which were left out, and a scoped run does not claim the
# whole.
#
# Log: zig-out/wsl/roll_probe.txt, this run's or absent. Exit 0 only if the production source passes its tests (RAN,
# not skipped) and every mutant is convicted by the test named for its rule. It builds a copy of the sources under
# $HOME and never touches this repository's tree; it boots nothing.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-roll-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/roll_probe.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  [ -f src/roll.zig ] || { echo "src/roll.zig is not there: nothing to probe"; exit 1; }
  verdict=0
  RL=src/roll.zig
  count=0
  skipped=0
  ONLY="$*"

  utest() { # $1 = label ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test "$RL" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|panic' "$S/$1.txt" | head -6
  }

  # one mutation: $1 = label, $2 = the sed program, $3 = a fragment of the name of the test that must convict it.
  # The mutant must differ from the source, compile, and be convicted by THAT test (its status line is not OK) --
  # not merely by something that stopped compiling.
  umutant() {
    # a scoped run (`roll_probe.sh r14 r48`) says what it left out, by name (PX): its green is not the full claim
    if [ -n "$ONLY" ] && ! echo " $ONLY " | grep -qF " ${1%%:*} "; then
      echo "skipped ${1%%:*}: not named"; skipped=$((skipped + 1)); return
    fi
    echo "=== $1 ==="
    count=$((count + 1))
    cp "$RL" "$RL.orig"
    sed -i "$2" "$RL"
    if cmp -s "$RL" "$RL.orig"; then echo "the mutation did not apply"; verdict=1; fi
    utest mutant
    if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($1)"; verdict=1; fi
    if grep -q 'error:' "$S/mutant.txt" && ! grep -qF "$3" "$S/mutant.txt"; then
      echo "THE NAMED TEST DID NOT RUN ($1): the mutant did not compile, or a test before it crashed the run -- that convicts nothing by its name"; grep -m3 'error:' "$S/mutant.txt"; verdict=1
    fi
    # the test's name and a failure's message share the line the runner prints, and its FAIL is on the next one, so
    # the name is what is asked for: convicted means the line of THAT test does not end in OK
    grep -F "$3" "$S/mutant.txt" | grep -vq '\.\.\.OK$' || { echo "MUTANT NOT CONVICTED BY ITS TEST ($1)"; verdict=1; }
    cp "$RL.orig" "$RL"; rm -f "$RL.orig"
  }

  echo "=== the production source, on Linux (uid $(id -u)) ==="
  utest production
  if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS"; verdict=1; fi
  if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the question was not asked"; verdict=1; fi
  grep -F "the verb reads a directory of brought records" "$S/production.txt" | grep -q '\.\.\.OK$' || { echo "the test of the verb did not run and pass"; verdict=1; }

  FILE="a roll is written as a file and read back in one spelling"
  TIME="a time is read in the two spellings the verb takes"
  READ="a record is read for whose it is, how far it goes and what the authority said of it"
  NAMED="is named for what it is"
  RET="a record heard under a retired key"
  CHAIN="a chain is named by the device that signed it"
  SINCE="against the roll before it, a record has written"
  MISSED="what a roll writes down is the last observation that was held"
  WHOLE="the whole set is called, and said in words"
  UNCLEAN="a record that does not verify, is nobody's, or is empty makes a roll that is not clean"
  ESTATE="a member whose machine stops declaring a journal is said"
  NONE="a fleet that keeps no record has nothing to call"
  FIND="statements that do not verify, are about no entry here, or disagree"
  VERB="the verb reads a directory of brought records"
  ONCE="is said once, and a member that leaves is said when it still owed an answer"
  BACK="a clock that went backwards between statements is a finding"
  SPAN="how long ago is said in the words a person says it"
  BLANK="a record with blank lines or carriage returns is counted as the journal counts it"

  # the roll as a file
  umutant "r1: a number may have a leading zero" "/if (s\.len > 1 and s\[0\] == .0.) return null;/d" "$FILE"
  umutant "r2: a name may be in capitals" "s/(c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_'/(c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_'/" "$FILE"
  umutant "r3: a hash may be in capitals" "s/(c >= 'a' and c <= 'f'))) return false;/(c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) return false;/" "$FILE"
  umutant "r4: a member may be on two lines" "/return error\.Malformed; \/\/ one line a member/d" "$FILE"
  umutant "r5: a roll may go on after its end" "/if (ended) return error\.Malformed;/d" "$FILE"
  umutant "r6: a head may have no entry behind it" "/if ((seen\.entries == 0) != (seen\.head == null)) return error\.Malformed;/d" "$FILE"
  umutant "r7: a date may be past the end of the entries" "/if (seen\.dated > seen\.entries) return error\.Malformed;/d" "$FILE"
  umutant "r8: entries may be dated with no time to say it by" "/if ((seen\.dated == 0) != (seen\.t == null)) return error\.Malformed;/d" "$FILE"
  umutant "r9: an anchor may have no roll that held it" "/if ((seen\.last == null) != (seen\.head == null)) return error\.Malformed;/d" "$FILE"
  umutant "r10: a member may have been held in the future" "/if (seen\.last) |l| if (l > at) return error\.Malformed;/d" "$FILE"
  umutant "r11: a held member may have been held by another roll" "/if (seen\.state == \.held and seen\.last != at) return error\.Malformed;/d" "$FILE"
  umutant "r12: a record may have diverged from nothing" "/if (seen\.state == \.diverged and seen\.head == null) return error\.Malformed;/d" "$FILE"
  umutant "r13: a fingerprint may be any length" "s/if (auth_text\.len != 16 or !isLowerHex(auth_text)) return error\.Malformed;/if (false) return error.Malformed;/" "$FILE"
  umutant "r14: a time may be later than a statement may state" "s/if (t > timeattest\.max_t) return null;/if (false) return null;/" "$FILE"
  umutant "r15: a name may not be as long as a name may be" "s/if (s\.len == 0) return false;/if (s.len == 0 or s.len > 64) return false;/" "$FILE"

  # the time the verb takes
  umutant "r16: a date the calendar has not is read as another moment" "s/if (c\.year != year or c\.month != month or c\.day != day or c\.hour != hour or c\.minute != minute or c\.second != second) return null;/_ = c;/" "$TIME"
  umutant "r17: a sign is a digit of a date" "/for (s) |c| if (c < '0' or c > '9') return null;/d" "$TIME"

  # a record, read
  umutant "r18: a statement dates only the entry it names" "s/for (0\.\.idx + 1) |i| {/for (idx..idx + 1) |i| {/" "$READ"
  umutant "r19: the latest bound is the best" "s/if (bounds\[i\] == null or st\.t < bounds\[i\]\.?) bounds\[i\] = st\.t;/if (bounds[i] == null or st.t > bounds[i].?) bounds[i] = st.t;/" "$READ"
  umutant "r20: a statement nobody verified is taken" "s/if (timeattest\.verify(line, auth\.key) != \.ok) {/if (false and timeattest.verify(line, auth.key) != .ok) {/" "$READ"
  umutant "r21: a statement about no entry here is taken without a word" "s/r\.foreign += 1;/_ = \&r;/" "$READ"
  umutant "r22: a statement that does not verify is taken without a word" "s/r\.refused += 1;/_ = \&r;/" "$READ"
  umutant "r23: the anchor is a line without its signature, which two devices of one design share" "s/digests\[i\] = timeattest\.entryDigest(line);/digests[i] = timeattest.entryDigest(line[0 .. std.mem.indexOf(u8, line, \" sig=\") orelse line.len]);/" "$READ"
  umutant "r24: the newest dated entry is the first" "s/^    var dated: usize = 0;\$/    var dated: usize = 1;/" "$READ"
  umutant "r25: the newest bound is the first" "s/if (dated > 0) r\.seen\.t = bounds\[dated - 1\];/if (dated > 0) r.seen.t = bounds[0];/" "$READ"
  umutant "r26: a retired key is not heard" "/\.retired_verified => |x| {\$/{n;s/\.held/.broken/}" "$RET"
  umutant "r27: a member no key ever signed for is not enrolled" "s/r\.seen\.state = \.unsigned;/r.seen.state = .unenrolled;/" "$RET"
  umutant "r28: a key nobody enrolled is a key" "s/r\.seen\.state = \.unenrolled;/r.seen.state = .held;/" "$NAMED"
  umutant "r29: a record nobody brought is one that is empty" "s/r\.seen\.state = \.absent;/r.seen.state = .empty;/" "$NAMED"
  umutant "r30: a record of nothing is one nobody brought" "s/r\.seen\.state = \.empty;/r.seen.state = .absent;/" "$NAMED"
  umutant "r31: a record nobody can vouch for has a break to place" "/if (r\.broken_at == null) return \.{ \.unvouched = old };/d" "$RET"

  # against the roll before
  umutant "r32: a record shorter than the roll saw is the roll's record" "/if (n < old\.entries) return \.{ \.shorter = old };/d" "$CHAIN"
  umutant "r33: the anchor is not looked for" "s/if (!std\.mem\.eql(u8, \&r\.digests\[old\.entries - 1\], \&old\.head\.?)) return \.{ \.forked = old };/if (false) return .{ .forked = old };/" "$CHAIN"
  umutant "r34: a record that has not grown has" "/if (n == old\.entries) return \.{ \.silent = old };/d" "$SINCE"
  umutant "r35: the first new entry's bound is read from the last" "s/const first_bound = r\.bounds\[old\.entries\];/const first_bound = r.bounds[n - 1];/" "$SINCE"
  umutant "r36: the undated are the dated" "s/if (b == null) undated += 1;/if (b != null) undated += 1;/" "$SINCE"
  umutant "r37: a member nobody brought was never there" "s/\.absent => return \.{ \.absent_since = old },/.absent => return .{ .no_anchor = old },/" "$SINCE"
  umutant "r38: a break after what the roll vouched for is a break inside it" "s/return \.{ \.broken_after = old };/return .{ .broken_within = old };/" "$SINCE"
  umutant "r39: a roll that could not vouch for a member is compared with all the same" "s/if (old\.head == null) return \.{ \.no_anchor = old };/if (false) return .{ .no_anchor = old };/" "$SINCE"
  umutant "r40: a member the roll did not have is old" "s/orelse return if (keeps) \.new else \.nothing;/orelse return if (keeps) .first else .nothing;/" "$SINCE"
  umutant "r41: a machine that no longer keeps a record is forgotten" "s/if (!keeps) return if (old\.head != null and old\.state != \.none) \.{ \.no_longer = old } else \.nothing;/if (!keeps) return .nothing;/" "$SINCE"
  umutant "r42: a date before the roll that did not have the entry is not stale" "s/const stale = if (first_bound) |t| (if (old\.last) |l| t < l else false) else false;/const stale = false;/" "$SINCE"
  umutant "r43: stale is the other way round" "s/(if (old\.last) |l| t < l else false)/(if (old.last) |l| t > l else false)/" "$SINCE"

  # what a roll keeps
  umutant "r44: a record that went backwards is adopted as the anchor" "s/\.shorter, \.forked => false,/.shorter, .forked => true,/" "$MISSED"
  umutant "r45: the entries are not carried across a roll that could not hold the member" "s/s\.entries = o\.entries;/s.entries = 0;/" "$MISSED"
  umutant "r46: nor is the time of the roll that held them" "s/s\.last = o\.last;/s.last = null;/" "$MISSED"
  umutant "r47: a diverged record is not said to be" "/if (r\.seen\.state == \.held) s\.state = \.diverged;/d" "$MISSED"
  umutant "r48: an adopted observation is stamped with a time that is not its roll's" "s/s\.last = at;/s.last = at + 1;/" "$MISSED"
  umutant "r49: the roll writes what it saw, not what it holds" "s/const kept_now = stored(since, r, change, at);/const kept_now = r.seen;/" "$WHOLE"

  # the verdict
  umutant "r50: an absent member is not a thing the set owes an answer for" "/\.absent => {\$/{n;d}" "$WHOLE"
  umutant "r51: a diverged record is not either" "/\.shorter => |old| {\$/{n;n;d}" "$WHOLE"
  umutant "r52: nor is a forked one" "/\.forked => |old| {\$/{n;n;d}" "$CHAIN"
  umutant "r53: nor is a member nobody enrolled" "/\.unenrolled => {\$/{n;d}" "$UNCLEAN"
  umutant "r54: nor is a record of nothing" "/\.empty => {\$/{n;d}" "$UNCLEAN"
  umutant "r55: nor is a record no key it held signed" "/\.unsigned => {\$/{n;d}" "$UNCLEAN"
  umutant "r56: nor is a record that does not verify" "/\.broken => {\$/{n;d}" "$UNCLEAN"
  umutant "r57: a statement that did not verify is not either" "/if (r\.refused > 0) {\$/{n;d}" "$FIND"
  umutant "r58: nor is one about no entry here" "/if (r\.foreign > 0) {\$/{n;d}" "$FIND"
  umutant "r59: nor is a copy the authority's date contradicts" "/if (w\.stale) {\$/{n;d}" "$FIND"
  umutant "r60: nor is a machine that stopped declaring a record" "/\.no_longer => |old| {\$/{n;d}" "$ESTATE"
  umutant "r61: a roll of nothing is clean" "/if (keepers == 0) {\$/{n;d}" "$NONE"

  # the words a person acts on
  umutant "r62: a member that left the fleet is not counted" "s/n_gone += 1;/_ = \&n_gone;/" "$WHOLE"
  umutant "r63: every member the roll had has left" "s/if (f\.member(old\.name) != null or /if (false or /" "$WHOLE"
  umutant "r64: a clock that reads before the roll is compared with is a span" "s/if (at >= p\.at) {/if (true) {/" "$WHOLE"
  umutant "r65: another authority's roll is the same clock" "s/and !std\.mem\.eql(u8, \&authority\.?\.fingerprint, \&p\.authority\.?)) {/and false) {/" "$WHOLE"
  umutant "r66: a roll of another fleet is compared with" "s/if (!std\.mem\.eql(u8, since\.?\.fleet, f\.name)) {/if (false) {/" "$VERB"
  umutant "r67: an hour is a minute" "s/const h = (s % 86400) \/ 3600;/const h = (s % 86400) \/ 60;/" "$WHOLE"
  umutant "r68: one is many" "s/return if (n == 1) one else many;/return if (n == 2) one else many;/" "$WHOLE"
  umutant "r69: a month is not two digits" "s/{d:0>4}-{d:0>2}-/{d:0>4}-{d}-/" "$VERB"
  umutant "r70: a second is a minute" "s/c\.hour, c\.minute, c\.second }/c.hour, c.minute, c.minute }/" "$FIND"
  umutant "r71: a record brought for a machine that keeps none is read without a word" "s/if (mine\.record != null) try out\.print(/if (false) try out.print(/" "$NONE"

  # what the review of the reworked module found, and the rules it said no test would catch
  umutant "r72: a member that left with something outstanding is not a finding" "s/if (old\.head != null and old\.state != \.held and old\.state != \.none) {/if (false) {/" "$ONCE"
  umutant "r73: a machine that stopped declaring a record is said at every roll" "s/return if (old\.head != null and old\.state != \.none) \.{ \.no_longer = old } else \.nothing;/return if (old.head != null) .{ .no_longer = old } else .nothing;/" "$ONCE"
  umutant "r74: a record that went backwards is counted as held" "s/if (kept_now\.state == \.held) n_held += 1;/if (r.seen.state == .held) n_held += 1;/" "$CHAIN"
  umutant "r75: a clock that went backwards between statements is not counted" "s/r\.backwards += 1;/_ = \&r;/" "$BACK"
  umutant "r76: nor is it a finding" "/if (r\.backwards > 0) {\$/{n;d}" "$BACK"
  umutant "r77: a day is said as an hour" "s/std\.fmt\.bufPrint(buf, \"{d} d {d} h\", .{ d, h })/std.fmt.bufPrint(buf, \"{d} d {d} h\", .{ h, d })/" "$SPAN"
  umutant "r78: a date equal to the roll's is a stale copy" "s/(if (old\.last) |l| t < l else false)/(if (old.last) |l| t <= l else false)/" "$BACK"
  umutant "r79: a blank line is an entry" "/^fn entryLines/,/^}/{/if (line\.len == 0) continue;/d}" "$BLANK"
  umutant "r80: a record that cannot be read is a record nobody brought" "s/return error\.Reported;/return null;/" "$VERB"
  umutant "r81: a directory that is not there is not an error" "/var brought_dir = std\.fs\.cwd()\.openDir/,/^    };/{s/return 1;/return 0;/}" "$VERB"
  umutant "r82: a file brought for a machine that keeps none is read" "s/std\.fs\.cwd()\.access(rp, \.{}) catch continue;/_ = readIf(arena, rp, out) catch return 1;/" "$VERB"
  umutant "r83: a clock behind the roll before is refused without saying why" "s/if (since) |back| if (as_of < back\.at) {/if (since) |back| if (as_of < back.at and false) {/" "$VERB"
  umutant "r84: a roll that does not read back is written" "s/if (!readsBack(arena, text)) {/if (false) {/" "$VERB"
  umutant "r85: a first roll that is not kept does not say so" "s/} else if (since == null) {/} else if (false) {/" "$VERB"
  umutant "r86: a header may have a word too many" "/if (ht\.next() != null) return error\.Malformed;/d" "$FILE"
  umutant "r87: so may a member's line" "/if (mt\.next() != null) return error\.Malformed;/d" "$FILE"
  umutant "r88: a fleet may be named in capitals, or not at all" "/if (!plainName(fleet_name)) return error\.Malformed;/d" "$FILE"
  umutant "r89: a head may be a character short" "s/if (head_text\.len != 64 or !isLowerHex(head_text)) return error\.Malformed;/if (!isLowerHex(head_text)) return error.Malformed;/" "$FILE"

  echo "=== verdict ==="
  echo "$count mutants run, $skipped left out"
  if [ "$verdict" -eq 0 ] && [ "$skipped" -gt 0 ]; then
    echo "PROBED (scoped): the production source passes its tests and the $count named mutants are convicted; $skipped were not run, so this is not the full claim"
  elif [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production source passes its tests, none skipped, and every mutant is convicted by the test named for its rule"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
