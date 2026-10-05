#!/bin/bash
# ringserv_nonroot.sh -- the first server as an identity of its own, measured OUTSIDE the machine (OWN-1).
#
# machines/ringserv.pack runs RingServ as the identity `appserver`, from /, with an empty environment, and the
# directory PID 1 hands it is where it keeps what it keeps. Before a boot is asked to show that, this asks
# the question where it is cheap and a failure names itself: can the same binary, running the pack's own
# command as an unprivileged user in that position, serve and keep its database in that directory?
#
#   - it serves GET /health with a 200
#   - the process is the identity: uid and gid 2000 in /proc, for every id the kernel keeps (real, effective,
#     saved, filesystem)
#   - its database, and the WAL and shared-memory files beside it, are in the directory it was given and are
#     that identity's
#   - the identity made nothing else in the places this looks: the probe's own tree, /tmp, /var/tmp, /dev/shm
#
# And the probe is judged the way a probe must be: it runs a SECOND time with the server as root, and must
# convict that run. A probe that cannot tell an unprivileged server from a privileged one measures nothing.
#
# What it does not show, and says so. This host is not the machine: an unprivileged user here can write
# elsewhere (the three places above are looked at; the rest of the filesystem is not), and the machine's
# image gives it nowhere but its directory. The probe's copy of the application declares a table, so that a
# database file exists at all: the application the machine places declares none, because creating one at
# startup took longer than RingServ's own 2000 ms wait under the emulator, as root too (measured), so a boot
# of that machine leaves no database on its disk. That the SERVER, as that identity, keeps one in its
# directory is what this shows; that the MACHINE hands the directory over is what experiment/os9_cloud.sh
# shows, from the disk the boot leaves.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/ringserv_nonroot.sh
#
# Needs: root (setpriv drops to the identity from there), curl, the server built by
# experiment/ringserv_build.ps1. Log: zig-out/wsl/ringserv_nonroot.txt, this run's or absent. Exit 0 only if
# the run as the identity passes every statement above AND the run as root is convicted.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
BIN=$R/zig-out/ringserv/ringserv
W=/tmp/harb-rs-nonroot
ID=2000
LOG=$R/zig-out/wsl/ringserv_nonroot.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  FAILS=0
  fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
  [ -x "$BIN" ] || { echo "no RingServ at $BIN (powershell experiment/ringserv_build.ps1)"; echo "exit 1"; exit 1; }
  [ "$(id -u)" -eq 0 ] || { echo "run as root: setpriv drops to the identity from there"; echo "exit 1"; exit 1; }
  command -v setpriv > /dev/null || { echo "no setpriv"; echo "exit 1"; exit 1; }
  command -v curl > /dev/null || { echo "no curl"; echo "exit 1"; exit 1; }

  # one run of the server as uid $1, and every statement above asked of it; the failures are counted in FAILS
  one() {
    FAILS=0
    pkill -f "$W/ringserv" 2> /dev/null; sleep 1
    rm -rf "$W" "$W.marker"; mkdir -p "$W/data" "$W/app"
    cp "$BIN" "$W/ringserv"; chmod 755 "$W/ringserv"
    # the application the machine places, plus one table: the probe wants a database FILE
    { sed '/^RingServ(\[/,$d' "$R/machines/ringserv/app.ring"
      echo 'RingServ(['
      echo '    :port = 8210,'
      echo '    :announce = 0,'
      echo '    :workers = 2,'
      echo '    :database = "ringserv.db",'
      echo '    :data = [ :guests = [ :name = :text ] ],'
      echo '    :services = [ :hello = [ :greet = func oReq { return Reply(:ok, [ :message = "hello" ]) } ] ]'
      echo '])'
    } > "$W/app/app.ring"
    chmod 755 "$W" "$W/app"; chmod 644 "$W/app/app.ring"
    # what PID 1 does for a world that declares STATE: a directory of its own, closed to everyone else
    chown "$ID:$ID" "$W/data"; chmod 700 "$W/data"
    : > "$W.marker"; sleep 1

    echo "--- the server, as uid $1, from /, with an empty environment, the pack's own command"
    ( cd / && env -i setpriv --reuid="$1" --regid="$1" --clear-groups \
        "$W/ringserv" run "$W/app/app.ring" --data "$W/data" > "$W/server.log" 2>&1 ) &
    code=000
    for _ in $(seq 1 50); do
      code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8210/health 2> /dev/null)
      [ "$code" = 200 ] && break
      sleep 0.2
    done
    echo "GET /health -> $code"
    [ "$code" = 200 ] || fail "the server did not answer /health with 200"

    pid=$(pgrep -f "$W/ringserv run" | head -1)
    if [ -z "$pid" ]; then
      fail "no server process"
    else
      ids=$(grep -E '^(Uid|Gid):' "/proc/$pid/status" | tr -s '\t' ' ' | tr '\n' ' ')
      echo "pid $pid: $ids"
      case "$ids" in
        "Uid: $ID $ID $ID $ID Gid: $ID $ID $ID $ID ") ;;
        *) fail "the process is not the identity in every id the kernel keeps" ;;
      esac
    fi

    ls -ln "$W/data"
    [ -s "$W/data/ringserv.db" ] || fail "no database file in its directory"
    for f in "$W"/data/*; do
      [ -e "$f" ] || continue
      o=$(stat -c '%u:%g' "$f")
      [ "$o" = "$ID:$ID" ] || fail "$f is $o, not the identity's"
    done
    stray=$(find "$W" -user "$ID" -not -path "$W/data" -not -path "$W/data/*" 2> /dev/null)
    stray="$stray$(find /tmp /var/tmp /dev/shm -xdev -user "$ID" -newer "$W.marker" -not -path "$W" -not -path "$W/*" -not -path "$W.marker" 2> /dev/null)"
    if [ -n "$stray" ]; then fail "the identity made something outside its directory: $stray"; else echo "nothing made by the identity outside its directory, in the places looked at"; fi

    pkill -f "$W/ringserv run" 2> /dev/null; sleep 1
    rm -rf "$W" "$W.marker"
  }

  echo "=== as the identity: every statement must hold ==="
  one "$ID"
  as_id=$FAILS
  echo "=== as root: the same probe must CONVICT it, or it measures nothing ==="
  one 0
  as_root=$FAILS

  echo "=== verdict ==="
  verdict=0
  if [ "$as_id" -ne 0 ]; then echo "the run as the identity failed $as_id statement(s)"; verdict=1; fi
  if [ "$as_root" -eq 0 ]; then echo "THE PROBE DID NOT CONVICT A ROOT SERVER: it cannot tell the two apart"; verdict=1; else echo "the run as root was convicted ($as_root statement(s) failed), as it must be"; fi
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the first server, as an unprivileged identity from /, serves and keeps its database in the directory it was given, and the probe convicts the same server as root"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
