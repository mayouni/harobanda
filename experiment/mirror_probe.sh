#!/bin/bash
# mirror_probe.sh -- a copy is the source's word, and every rule that says so is convicted when it is broken (MIR-1).
#
# The mirror seat (STZ-OS-RULING-19) is the messages and their judgement (src/mirror.zig), the acts that touch a kernel
# (src/mirrorserve.zig), and the rules of two grammars that say who may give a copy and who may keep one (src/machine.zig,
# src/fleet.zig). A guard that has never been seen to convict is a claim, and a court that never convicts is as useless
# as one that always does (VDCT-1). So this runs each of them against scratch copies of the source with ONE mutation
# each, and requires every mutant to be convicted -- by the test, or the fixture, named for the rule it breaks:
#
#   units    the tests of the two files, on Linux (a walk that follows no link, a copy read over a real socket, a swap cut
#              short, a source that lies), then mutants of them: the signature not checked / the source not checked / the
#              device not checked / a replayed listing taken / a request from another key answered / a request that
#              answers another challenge answered / a request whose signature is not checked / an uppercase spelling taken
#              for the same bytes / a number with a leading zero / a path that climbs out / a name with a control byte or a
#              backslash / entries out of order / a file that is also a directory / a digest not checked / a file the
#              listing does not list kept / a link taken for a file / a name the court does not know / a link in the path
#              of the directory followed / a link in it taken for a file / a link not named / a file that is not the
#              world's given / a pipe given / a name that cannot be carried given / entries unsorted / a listing not held
#              to the request / a file's bytes not held to their digest / a swap cut short not undone, not finished, and
#              not cleaned up / a refusal's words that could start a line
#   courts   the machine, fleet and pack courts, then mutants of the machine grammar's mirror rules and of the fleet's,
#              each convicted by the fixture named for its rule (a refusal that is computed and not returned, a condition
#              dropped, a bound moved). A mutant that makes the court CRASH on the case is convicted too, and the probe
#              says so: it is the case that reached the code
#   all      both (the default)
#
# What it does not reach, and says: the filesystem boundary of the walk (a directory on another filesystem than the one it
# lies in) needs a second filesystem a unit test cannot make; the walk's second look at a file's owner while it is being
# streamed is a race, which a test cannot win on purpose; and the read-back of what the puller wrote is caught first by the
# per-file digest, so removing it changes nothing a test can see -- it is what a disk that lies about a write would be
# convicted by, and no test has such a disk. The scene (experiment/os12_mirror.sh) boots the rest, and its negatives are
# read off two machines' disks.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/mirror_probe.sh [units|courts|all]
#
# Log: zig-out/wsl/mirror_probe_<mode>.txt, this run's or absent. Exit 0 only if the production source passes (and its tests
# RAN, not skipped) and every mutant is convicted by the case named for it. It builds a copy of the sources under $HOME and
# never touches this repository's tree; it boots nothing.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
MODE=${1:-all}
case "$MODE" in units|courts|all) ;; *) echo "usage: mirror_probe.sh [units|courts|all]"; exit 2 ;; esac
S=$HOME/harb-mirror-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/mirror_probe_$MODE.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'pub fn attempt' src/mirrorserve.zig || { echo "src/mirrorserve.zig has no attempt: nothing to probe"; exit 1; }
  verdict=0
  MR=src/mirror.zig; SV=src/mirrorserve.zig; MC=src/machine.zig; FL=src/fleet.zig

  # ---- the tests ------------------------------------------------------------------------------------
  utest() { # $1 = label, $2 = the file whose tests are run ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test "$2" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|panic' "$S/$1.txt" | head -6
  }

  # one mutation: $1 = label, $2 = the file mutated, $3 = the sed program, $4 = the file whose tests are run, $5 = a
  # fragment of the name of the test that must convict it. The mutant must differ from the source, compile, and be
  # convicted by THAT test (its status line is not OK) -- not merely by something that stopped compiling.
  umutant() {
    echo "=== $1 ==="
    cp "$2" "$2.orig"
    sed -i "$3" "$2"
    if cmp -s "$2" "$2.orig"; then echo "the mutation did not apply"; verdict=1; fi
    utest mutant "$4"
    if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($1)"; verdict=1; fi
    if grep -q 'error:' "$S/mutant.txt" && ! grep -qF "$5" "$S/mutant.txt"; then
      echo "MUTANT DID NOT COMPILE ($1): that convicts nothing"; grep -m3 'error:' "$S/mutant.txt"; verdict=1
    fi
    # the test's name and a failure's message share the line the runner prints, and its FAIL is on the next one, so the
    # name is what is asked for: convicted means the line of THAT test does not end in OK
    grep -F "$5" "$S/mutant.txt" | grep -vq '\.\.\.OK$' || { echo "MUTANT NOT CONVICTED BY ITS TEST ($1)"; verdict=1; }
    cp "$2.orig" "$2"; rm -f "$2.orig"
  }

  if [ "$MODE" = units ] || [ "$MODE" = all ]; then
    echo "=== the production source, on Linux (uid $(id -u)) ==="
    for f in $MR $SV; do
      utest production "$f"
      if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS ($f)"; verdict=1; fi
      # the tests must have RUN, not been skipped: a skip is no witness
      if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the question was not asked ($f)"; verdict=1; fi
    done
    grep -F "keeps exactly that, or nothing" "$S/production.txt" | grep -q '\.\.\.OK$' || { echo "the test over a real socket did not run and pass"; verdict=1; }

    # the signed listing, and who may ask for it
    umutant "u1: the signature of a listing is not checked" $MR 's#Ed25519\.Signature\.fromBytes(m\.sig)\.verify(text\[0\.\.m\.signed_len\], source) catch return \.{ \.bad = \.bad_signature };#_ = m.sig;#' $MR "refused for its own reason"
    umutant "u2: a listing signed by somebody else is the source's" $MR 's#if (!std\.mem\.eql(u8, &fp, &m\.source)) return \.{ \.bad = \.wrong_source };#_ = \&fp;#' $MR "refused for its own reason"
    umutant "u3: a listing cut for another device is this device's" $MR 's#if (puller) |p| if (!std\.mem\.eql(u8, &p, &m\.puller)) return \.{ \.bad = \.wrong_puller };#_ = puller;#' $MR "refused for its own reason"
    umutant "u4: a listing that answers another request is this one's" $MR 's#if (nonce) |n| if (!std\.mem\.eql(u8, &n, &m\.nonce)) return \.{ \.bad = \.wrong_nonce };#_ = nonce;#' $MR "refused for its own reason"
    umutant "u5: a request from another key is answered" $MR '/if (!std\.mem\.eql(u8, &r\.key, &allowed\.toBytes())) return null;/d' $MR "the puller's word only for the key"
    umutant "u6: a request that answers another challenge is answered" $MR 's#if (!std\.mem\.eql(u8, &r\.a, &a)) return null;#_ = a;#' $MR "the puller's word only for the key"
    umutant "u7: a request's signature is not checked" $MR 's#Ed25519\.Signature\.fromBytes(r\.sig)\.verify(body, allowed) catch return null;#_ = body;#' $MR "the puller's word only for the key"
    # one spelling of everything
    umutant "u8: an uppercase spelling is taken for the same bytes" $MR 's#for (s) |c| if (!std\.ascii\.isHex(c) or std\.ascii\.isUpper(c)) return false;#for (s) |c| if (!std.ascii.isHex(c)) return false;#' $MR "has one spelling"
    umutant "u9: a number may have a leading zero" $MR '/if (s\.len > 1 and s\[0\] == .0.) return null;/d' $MR "has one spelling"
    umutant "u10: a path may climb out of its directory" $MR 's# or std\.mem\.eql(u8, c, "\.\.")##' $MR "has one spelling"
    umutant "u11: a path may carry a control byte" $MR 's#b < 0x20 or ##' $MR "has one spelling"
    umutant "u12: a path may carry a backslash" $MR 's# or b == \x27\\\\\x27##' $MR "has one spelling"
    umutant "u13: entries need not be in order" $MR 's#if (i > 0 and !std\.mem\.lessThan(u8, entries\[i - 1\]\.path, e\.path)) {#if (false and i > 0 and !std.mem.lessThan(u8, entries[i - 1].path, e.path)) {#' $MR "has one spelling"
    umutant "u14: a file may also be a directory" $MR 's#if (files\.contains(e\.path\[0\.\.slash\])) return#if (false and files.contains(e.path[0..slash])) return#' $MR "has one spelling"

    # a copy read against its listing
    umutant "u15: a file's digest is not checked" $MR 's#if (!std\.mem\.eql(u8, &got\.digest, &e\.digest)) {#if (false and !std.mem.eql(u8, \&got.digest, \&e.digest)) {#' $MR "is read against its manifest"
    umutant "u16: a file the listing does not list is kept" $MR 's#if (!listed\.contains(here)) {#if (false and !listed.contains(here)) {#' $MR "is read against its manifest"
    umutant "u17: a link is taken for a file" $MR 's#if (underLink(dir, e\.path)) {#if (false and underLink(dir, e.path)) {#' $MR "symbolic link is not a copy"
    umutant "u18: a name the court does not know" $MR 's#pub const kept_manifest_suffix = "\.manifest";#pub const kept_manifest_suffix = ".mf";#' $SV "names the floor makes for a copy"

    # the walk: the part of the seat that is dangerous
    umutant "u19: a link in the path of the directory is followed" $SV 's#const open_dir: posix\.O = \.{ \.ACCMODE = \.RDONLY, \.DIRECTORY = true, \.NOFOLLOW = true, \.CLOEXEC = true };#const open_dir: posix.O = .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .NOFOLLOW = false, .CLOEXEC = true };#' $SV "unmirrorable, and says which"
    umutant "u20: a link in the directory is read as what it points at" $SV 's#posix\.fstatat(fd, ent\.name, linux\.AT\.SYMLINK_NOFOLLOW)#posix.fstatat(fd, ent.name, 0)#' $SV "unmirrorable, and says which"
    umutant "u21: a link is not named" $SV 's#if (linux\.S\.ISLNK(st\.mode)) return self\.refuse(#if (false and linux.S.ISLNK(st.mode)) return self.refuse(#' $SV "unmirrorable, and says which"
    umutant "u22: a file the world does not own is given" $SV 's#if (st\.uid != self\.uid) return self\.refuse(#if (false and st.uid != self.uid) return self.refuse(#' $SV "another identity owns is refused"
    umutant "u23: a pipe is given" $SV 's#} else if (linux\.S\.ISREG(st\.mode)) {#} else if (true) {#' $SV "unmirrorable, and says which"
    umutant "u24: a name that cannot be carried is given" $SV 's#if (!mirror\.safeRelPath(rel)) return self\.refuse(#if (false and !mirror.safeRelPath(rel)) return self.refuse(#' $SV "unmirrorable, and says which"
    umutant "u25: the entries are not sorted" $SV '/mirror\.sortEntries(w\.list\.items);/d' $SV "a walk gives what the world owns"
    umutant "u25b: a file longer than a copy can carry is read to its end" $SV 's#if (@as(u64, @intCast(st2\.size)) > room) return self\.refuse(#if (false and @as(u64, @intCast(st2.size)) > room) return self.refuse(#' $SV "longer than a copy can carry"

    # a keeper takes only what the source signed
    umutant "u26: a listing is not held to the request it answers" $SV 's#mirror\.verify(alloc, text\.items, source, me, nonce_b)#mirror.verify(alloc, text.items, source, me, null)#' $SV "replays, lies about a file"
    umutant "u27: a file's bytes are not held to the digest the listing carries" $SV 's#if (!std\.mem\.eql(u8, &d, &e\.digest)) return \.{ \.unverified = std\.fmt\.allocPrint(alloc, "{s} does not match the digest the source signed for it"#if (false and !std.mem.eql(u8, \&d, \&e.digest)) return .{ .unverified = std.fmt.allocPrint(alloc, "{s} does not match the digest the source signed for it"#' $SV "replays, lies about a file"

    # a swap cut short at any step
    umutant "u28: a copy set aside and not put back" $SV 's#if (!exists(into) and exists(old)) cwd\.rename(old, into) catch {};#if (false and !exists(into) and exists(old)) cwd.rename(old, into) catch {};#' $SV "a swap cut short"
    umutant "u29: a record that waited for its copy is not finished" $SV 's#if (exists(man_new) and !exists(new) and exists(into)) cwd\.rename(man_new, man) catch {};#if (false and exists(man_new) and !exists(new) and exists(into)) cwd.rename(man_new, man) catch {};#' $SV "a swap cut short"
    umutant "u30: a pull that was never finished is not cleaned up" $SV '/^    cwd\.deleteTree(new) catch {};$/d' $SV "a swap cut short"

    # what is written on the wire cannot be a second line
    umutant "u31: a refusal's words may carry a line end" $SV 's#= if (c < 0x20 or c == 0x7f) \x27?\x27 else c;#= c;#' $SV "an outcome is one line"
  fi

  # ---- the courts -----------------------------------------------------------------------------------
  if [ "$MODE" = courts ] || [ "$MODE" = all ]; then
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
    # a value that is not there where the rule says so, taken for granted: the court reaches the line and falls over it
    NU='s/orelse return ctx\.refuse(.*$/orelse unreachable;/'

    cmutant "c1: a mirror on an edge machine" $MC "/a mirror is a hosted machine's declaration/$NR" machine R210
    cmutant "c2: both ends of a mirror on one machine" $MC "/this machine declares both ends of a mirror/$NR" machine R211
    cmutant "c3: a mirror signed by nobody" $MC '/const sign_key = identity orelse return/s#orelse return ctx\.refuse(.*$#orelse "/data/device.key";#' machine R212
    cmutant "c4: a copy given to whoever asks" $MC '/const fc = for_c orelse return/s#orelse return ctx\.refuse(.*$#orelse of;#' machine R213
    cmutant "c5: a directory to give and no link to give it on" $MC "/const net = server_net orelse return/ $NU" machine R214
    cmutant "c6: a link that gives a copy of nothing" $MC "/const of = of_c orelse return/ $NU" machine R215
    cmutant "c7: a source on a leased address" $MC "/asks for its own address by dhcp, and the address a copy is asked of/$NR" machine R216
    cmutant "c8: a port below 1024" $MC '/MIRROR_SERVER is the TCP port/s/port < 1024 or //' machine R217
    cmutant "c9: a source on a loopback" $MC "/which nobody else can ask: a mirror's source gives its copy on a link/$NR" machine R218
    cmutant "c10: a source on two links" $MC "/gives a copy too, and/$NR" machine R219
    cmutant "c11: a directory that is not plain names" $MC "/MIRROR_OF is an absolute path of plain names/$NR" machine R220
    cmutant "c12: a key in any spelling" $MC 's/if (for_text\.len != 64 or !lowerHex(for_text))/if (for_text.len != 64)/' machine R221
    cmutant "c13: a key no public key is written as" $MC '/MIRROR_FOR is an Ed25519 public key, and/s/catch return ctx\.refuse(.*$/catch {};/' machine R222
    cmutant "c14: a directory no world owns" $MC '/const world = owner orelse return/s#orelse return ctx\.refuse(.*$#orelse \&svc_slice[0];#' machine R223
    cmutant "c15: a directory in RAM" $MC '/const holder = holderOf(mount_slice, dir) orelse return/s#orelse return ctx\.refuse(.*$#orelse mount_slice[0];#' machine R224
    cmutant "c16: a directory on a filesystem that keeps no owners" $MC "/MIRROR_OF {s} lies inside MOUNT {s}, a {s} filesystem/$NR" machine R225
    cmutant "c17: a port a world declares" $MC "/MIRROR_SERVER {d} is a port {s} declares in PORTS/$NR" machine R226
    cmutant "c18: a source to take the word of with no key" $MC '/const kc = key_c orelse return/s#orelse return ctx\.refuse(.*$#orelse from;#' machine R227
    cmutant "c19: a copy with nowhere to be kept" $MC '/const ic = into_c orelse return/s#orelse return ctx\.refuse(.*$#orelse from;#' machine R228
    cmutant "c20: a place to keep a copy and nobody to take it from" $MC "/const from = from_c orelse return/ $NU" machine R229
    cmutant "c21: a port may be spelled with a leading zero" $MC '/^pub fn parseHostPort/,/^}/{/if (!plainDecimal(text\[colon + 1 \.\.\])) return null;/d}' machine R231
    cmutant "c22: a key of any length" $MC 's/if (key_text\.len != 64 or !lowerHex(key_text)) return ctx\.refuse(kc\.line/if (key_text.len != 64) return ctx.refuse(kc.line/' machine R251
    cmutant "c23: a key no public key is written as" $MC '/MIRROR_KEY is the source.s Ed25519 public key, and/s/catch return ctx\.refuse(.*$/catch {};/' machine R233
    cmutant "c24: a source with no way there" $MC "/MIRROR_FROM asks {s}, and this machine has no way there/$NR" machine R234
    cmutant "c25: a source over no network" $MC "/MIRROR_FROM asks over a network, and this machine declares none/$NR" machine R235
    cmutant "c26: a copy kept in no mount" $MC '/const holder = holderOf(mount_slice, into) orelse return/s#orelse return ctx\.refuse(.*$#orelse mount_slice[0];#' machine R236
    cmutant "c27: a copy swapped in at the root of a disk" $MC "/MIRROR_INTO {s} is the place itself/$NR" machine R237
    cmutant "c28: a copy on a filesystem that keeps no modes" $MC "/a copy of a world's directory is kept closed to everyone but the machine/$NR" machine R238
    cmutant "c29: a copy in RAM" $MC 's/if (holder\.fs != \.ext4) return ctx\.refuse(ic\.line,/if (holder.fs == .vfat) return ctx.refuse(ic.line,/' machine R239
    cmutant "c30: a copy on a disk nothing can write" $MC 's/for (holder\.options) |o| if (o == \.ro) return ctx\.refuse(ic\.line,/for (holder.options) |o| if (false and o == .ro) return ctx.refuse(ic.line,/' machine R240
    cmutant "c31: a copy in a world's place" $MC "/which overlaps {s}, the STATE of {s}/$NR" machine R241
    cmutant "c32: the names beside the copy are not the copy's" $MC 's/for (mirror_family) |suffix| {/for (mirror_family[0..1]) |suffix| {/' machine R242
    cmutant "c33: a copy made where the key is" $MC "/which is where IDENTITY {s} is/$NR" machine R243
    cmutant "c34: a copy made where the record is" $MC 's/if (journal) |rec| if (within(rec, name)) return ctx\.refuse(ic\.line,/if (journal) |rec| if (false and within(rec, name)) return ctx.refuse(ic.line,/' machine R244
    cmutant "c35: a copy made over the directory the key lives in" $MC 's/if (within(sign_key, name)) return ctx\.refuse(ic\.line/if (std.mem.eql(u8, sign_key, name)) return ctx.refuse(ic.line/' machine R245
    cmutant "c36: a pace under five seconds" $MC 's/if (n < mirror_every_min or n > mirror_every_max)/if (n > mirror_every_max)/' machine R246
    cmutant "c37: a pace over a day" $MC 's/if (n < mirror_every_min or n > mirror_every_max)/if (n < mirror_every_min)/' machine R247
    cmutant "c38: MIRROR_SERVER on a machine" $MC 's/"MIRROR_INTO", "MIRROR_EVERY" },/"MIRROR_INTO", "MIRROR_EVERY", "MIRROR_SERVER" },/' machine R248
    cmutant "c39: MIRROR_FROM on a network" $MC 's/"TIME_AUTHORITY", "MIRROR_SERVER" },/"TIME_AUTHORITY", "MIRROR_SERVER", "MIRROR_FROM" },/' machine R249
    cmutant "c40: a mirror in a machine file" $MC 's/\.MACHINE, \.SERVICE, \.CAPABILITY, \.MOUNT, \.PIN, \.NETWORK, \.USER, \.PEER => false,/.MACHINE, .SERVICE, .CAPABILITY, .MOUNT, .PIN, .NETWORK, .USER, .PEER, .MIRROR => false,/; s/\.RESIDENCY, \.MIRROR => true,/.RESIDENCY => true,/' machine R250
    cmutant "c41: a path that is not plain names, for a copy" $MC "/MIRROR_INTO is an absolute path of plain names/$NR" machine R252
    cmutant "c42: a copy kept in a directory the machine mounts itself" $MC 's/for (implicit_mounts) |imp| if (within(into, imp)) return ctx\.refuse(ic\.line,/for (implicit_mounts) |imp| if (false and within(into, imp)) return ctx.refuse(ic.line,/' machine R253

    cmutant "f1: a copy from a member nobody declared" $FL "/no MEMBER {s} is declared: a copy is given by a machine of this fleet/$NR" fleet FR74
    cmutant "f2: a copy to a member nobody declared" $FL "/no MEMBER {s} is declared: a copy is kept by a machine of this fleet/$NR" fleet FR75
    cmutant "f3: a copy kept where the original is" $FL "/copies {s} to itself/$NR" fleet FR76
    cmutant "f4: two keepers for one source" $FL "/already gives its copy to/$NR" fleet FR77
    cmutant "f5: two sources for one keeper" $FL "/already keeps the copy of/$NR" fleet FR78
    cmutant "f6: a chain of copies" $FL "/in a chain: a machine that gives a copy keeps none/$NR" fleet FR79
    cmutant "f7: a source that gives nothing" $FL "/const of = sm.machine.mirror_of orelse return/ $NU" fleet FR80
    cmutant "f8: a keeper that takes nothing" $FL "/const mf = dm.machine.mirror_from orelse return/ $NU" fleet FR81
    cmutant "f9: it asks another port than the source gives on" $FL 's/if (mf\.ip != at\.ip or mf\.port != wire\.mirror_server\.?) {/if (mf.ip != at.ip) {/' fleet FR82
    cmutant "f10: it asks another address than the source gives on" $FL 's/if (mf\.ip != at\.ip or mf\.port != wire\.mirror_server\.?) {/if (mf.port != wire.mirror_server.?) {/' fleet FR83
    cmutant "f11: a source nobody can check" $FL "/const skey = sm.key orelse return/ $NU" fleet FR84
    cmutant "f12: a keeper nobody can show to be the device" $FL "/const dkey = dm.key orelse return/ $NU" fleet FR85
    cmutant "f13: the keeper takes the word of another key" $FL "/the word it takes is not the source's/$NR" fleet FR86
    cmutant "f14: the source gives to another key" $FL "/somebody who is not the keeper/$NR" fleet FR87
    cmutant "f15: a question with no way there" $FL "/asks {s} for a copy, which gives it on/$NR" fleet FR88
    cmutant "f16: any link is a way there" $FL '/^fn checkMirrors/,/^}/s/ or f\.joined(n\.name, wire\.name)/ or true/' fleet FR88
    cmutant "f17: a source the fleet never named" $FL "/no MIRROR names it FROM/$NR" fleet FR89
    cmutant "f18: a keeper the fleet never named" $FL "/no MIRROR names it TO/$NR" fleet FR90
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
