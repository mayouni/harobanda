# TIME-1 — a record is dated by somebody else's word, or says it is undated

The floor has no date. The board has no clock of its own and nothing on the
boot path sets one, so a time the machine wrote into its own journal would be
the epoch wearing the authority of a date, and JRN-1 left the journal without
one on purpose. STZ-OS-RULING-07 (2026-09-27) decided where the trust in time
comes from: a time is ATTESTED, by an authority the fleet declares and enrols
like any member, and a machine with no source says its records are ORDERED and
UNDATED, in those words. STZ-OS-RULING-16 (2026-10-05) put it first on rung 3,
because a certificate is a dated claim and the floor has no date. This is the
seat, built, and what judged it.

## What was built

- **The statement** (`src/timeattest.zig`): `time authority=<fp> entry=<digest>
  t=<seconds> sig=<sig>`, Ed25519 over the exact bytes before ` sig=` -- the
  entry whose digest is `<digest>` existed no later than `<seconds>`. An UPPER
  bound: the authority was shown the digest, so the entry existed; nothing is
  said of how long before. **`<digest>` is the sha256 of the entry's whole
  written line, signature and all** (`entryDigest`), and the chain says the rest:
  every entry's hash covers the one before it. It is one spelling to the byte:
  lowercase hex, a time of digits with no sign, no separator and no leading zero,
  no more than one line end, a time the calendar can hold (`max_t`), and one the
  clock cannot have been set before (`earliest`: the authority will not sign it
  and an auditor will not take it). A bound is printed rounded UP to the minute.
- **The grammar**: `CLOCK`, `TIME_FROM` and `TIME_KEY` on a MACHINE,
  `TIME_AUTHORITY` on a NETWORK and on a FLEET. The machine court went from 173
  to 213 cases (A36-A43, R139-R170) and the fleet court from 60 to 71 (FA12,
  FR50-FR59). A clock is a real-time clock (`/dev/rtc`, `/dev/rtcN`), not any
  device; an endpoint is spelled one way; a question needs a way there (on a
  link's own prefix, a gateway, an EGRESS destination with a gateway to
  carry it, or a lease). The fleet
  court judges what no machine can: the one authority is a member, is enrolled,
  answers on a link; every machine that asks asks THAT address and port, takes
  THAT key's word (FR58), and has a way there (FR59).
- **The acts** (`src/timeserve.zig`, `src/init.zig`): the authority is PID 1
  forking a loop that reads the RTC at every question (`/dev/rtc0`, one ioctl)
  and answers `time? entry=<64 hex>` over UDP -- nothing it cannot stand behind:
  a clock that will not answer, or reads a time before 2026, is silence, never a
  time made up (`respond`). The responder is given nothing of PID 1's but its
  stdio and its socket (`closeInherited`), and its line is said only once it
  exists. The asker is PID 1, after it has written the journal's entry: three
  tries, two seconds apiece, and the answer is kept in `<journal>.time` only if
  `TIME_KEY` verifies it AND it names the entry asked (`keep` ends a file a power
  cut left without a last newline, so the next statement is not run onto the cut
  one). Said on the console and never in the ledger, so an authority that is down
  holds no trial back.
- **The auditor** (`src/timeaudit.zig`, `harb time verify <fleet> <statements>
  [<record>]`): checks a statement with the fleet's key alone and binds it to a
  record by recomputing each entry's digest. An entry is bounded by the EARLIEST
  statement at or after it; an entry after the last is ORDERED and UNDATED. A
  statement about an entry the record does not hold is refused: a record cut at
  its end still hashes and chains, and the statement about the entry that was cut
  is the only thing that says it used to be longer. It exits 1 on a statement that
  does not verify, on one that is not about the record, and on a file with no
  statement at all (a verification of nothing is not one). One reading, two
  callers: `harb journal` runs it from inside the machine with the key it was
  declared to take -- and REPORTS, never fails on, a kept statement that does not
  verify, because that witness is a service whose exit gates the trial's commit
  and time is advisory. For a machine that declares no `TIME_FROM` it says that its
  record is ORDERED and UNDATED (ruling 07, item 4) -- from the machine's second
  boot on, because the first prints "no record yet" and stops, and only for a machine
  that runs this witness: `makeen_box` keeps a record and runs none, and says nothing
  of time. (`qemu_identity.expected` and `fleet_temoin.expected` each gained that one
  line, read as a diff before it was pinned, and both boots were re-run against the
  re-pins.)
- **The journal's verifier** (`src/journal.zig`): an entry is the shape the file
  writes (`seq=<its place> prev=...`), and nothing else a device's key signed is one.
- **The scene** (`machines/time_clockbox.machine`, `machines/time_till.machine`,
  `machines/time_cloud.fleet`, `experiment/os10_time.sh`): see below.

## What judges it

- **The pinned scene, 557 lines, identical on two runs** (`machines/time.expected`):
  the authority booted alone makes its key and publishes it, and enrolment is
  somebody reading a line and writing it down, into COPIES of the fleet and of the
  till's declaration; then the till is booted three times with the authority on the
  wire (each boot's record is dated by a statement kept beside it, and the witness
  from inside says so), twice with the authority gone (what it had said stays said,
  the entries after it are `ORDERED and UNDATED`, no date made up), once answered by an
  IMPOSTOR -- a different machine on the authority's address, with a perfectly good
  signature of its own, refused at the door -- and once with a statement the power cut
  short on its disk, which the witness says is not a statement and does not fail on.
  Then two authorities that cannot keep what they declare, one whose clock will not
  answer and one with no link to answer on: each says so, does NOT say it answers, and
  so differs from what it expects. The disk, read back from the DISK (`debugfs`, after
  the journal is replayed on a copy), holds the three statements the authority gave,
  byte for byte, and none of the impostor's.
- **what the host can say with the fleet file and no secret**: the till's record
  dated (the authority's key) and attributed (the device's key, `harb fleet ...
  verify`) -- two questions, two keys; the record after the authority went away,
  mixed, with entry 4 undated; and six audits that must fail: a statement a second
  late, a fleet that takes its time from another machine, an entry taken out, the
  record cut at its end, nothing to verify, a fleet that takes its time from nobody.
- **the clock the statements read** is the emulator's: `-rtc base=2026-10-05T12:00:00,
  clock=vm`, a fixed point that runs with the virtual machine. The pin cannot hold a
  minute that depends on how fast an emulator booted (BDG-1), so the times are
  normalised and the script ASSERTS what the pin cannot: the first statement is no
  earlier than the base, each is LATER than the one before (a responder that kept its
  boot's reading states one second three times), all within half an hour.
- **the scene is itself probed** (`experiment/time_scene_probe.sh`, 23 minutes): in a
  scratch copy of the sources, five bugs the seat had or a review named are put back one
  at a time, the machine is built from each, the WHOLE scene is run, and it must fail on a
  line of the section the bug changes. **s1**, a witness that exits 1 on a kept statement
  that does not verify: the cut boot's `record (pid N) exited 0` is gone. **s2**, an asker
  that asks about the entry's public `hash=`: the `dated:` audit says every statement is
  about an entry the record does not hold. **s3**, a responder that keeps the clock it read
  at its first question: the `clock:` line says `no`. **s4**, an authority whose clock will
  not answer that says it answers: the `deadclock:` boot says it. **s5**, an asker that does
  not check the signature of the answer it keeps: the `disk:` line says the impostor's
  answer was kept. The unmutated copy matches the pin first, because a mutant convicted by
  a scene that was red already is no conviction. (Until a second review asked for it, "the
  scene convicts three put-back bugs" was a hand experiment that nobody could repeat.)
- **the unit tests**, on Linux with none skipped (`experiment/linux_test.sh`: 101
  tests): the statement and every way to damage or respell one, the calendar, the
  audit (and what cannot be bought in advance), the journal's shape, the RTC, the
  answer to one datagram, the cut line, the sweep (a forked child asked what it holds),
  and a wire test that asks a real socket and is answered by the authority, by an
  impostor, by the authority about ANOTHER entry, by the authority's own answer with
  twenty line ends after it, and by nobody.
- **the probe** (`experiment/time_probe.sh`): 31 mutants of those tests and 44 of the
  grammars' time rules (33 machine, 11 fleet), each in a scratch copy, each convicted by
  the case named for it. Its runs found: the machine court judged no boundary of a port
  and no `..` in a device path (A38-A40, R159-R162); the record test altered only a
  non-final entry, so every test passed with the entry's own hash check removed; and,
  after the review's fixes, the same thing twice more -- the chain check, shadowed by the
  entry's place, and the responder's made-up-time mutant, made equivalent by `sign`
  refusing zero -- each closed by the case only that check can fail. Mutants that did not compile
  convict nothing and were rewritten (Zig will not discard an error set, and an unused
  capture or parameter is an error). Two court mutants are convicted by a CRASH of the
  court on the case: the refusal they removed is what stands between a bad declaration
  and an integer cast or an unwrapped null. Its first production run on the widened
  machine court also found FR59 refused for the wrong reason: the machine court now
  refuses an asker with no way there before the fleet can say no route joins its link.
- **every other pinned boot is byte-identical**: the regression of all fourteen pinned
  scenes against the final binary -- except the two that carry the new `harb journal`
  line.

## What it found

An independent read-only review, after every gate was green, found these. Each was
checked against the code before it was acted on, and each fix has the case that now
convicts it.

- **A time could be bought for an entry before the device wrote it** (HIGH, design). The
  entry's `hash=` is a hash of public bytes, and the question carries the hash before it
  in the clear, so anybody could compute the next entry's hash, ask the authority its
  time, and hold a genuine signature; and two devices running one machine file share one
  `hash=` chain, so one's statements bound to the other's record. A statement now names
  the digest of the whole written line. With the old behaviour put back the scene fails
  and says why.
- **A genuine answer with twenty line ends after it panicked PID 1** (MEDIUM). `parse`
  trimmed any number of line ends, the datagram was longer than the buffer a statement is
  kept in, and the copy was out of bounds in the process that reads the wire. One line end
  at most, the kept line is the trimmed one, and a wire test sends exactly that.
- **The responder inherited the hardware watchdog** (MEDIUM, latent): a fork that is never
  exec'd keeps what close-on-exec exists to drop. It is given nothing but stdio and its
  socket, asked of the kernel by a test that forks. (No machine can be both A/B-slotted and
  an authority today, so no boot could ever have shown it.)
- **A statement was a valid journal entry of the authority's own record** (MEDIUM-LOW): the
  same key signs both, and a caller chooses part of a statement's text. The journal's
  verifier and the auditor take only the shape the file writes.
- **Two spellings of one statement verified** (`+N`, `000N`, `1_000`), against the claim
  that the signature is over the bytes on the line. One spelling, checked over the line.
- **A fork that failed announced a promise it could not keep**: the line was said before the
  fork, so the boot matched its expectation and committed with no authority. It is said after.
- **Claims no boot, pin or mutant showed**: that the clock is read at every question
  (now asserted, and convicted); that an authority says it answers only if the hardware
  answered (two boots in the scene); that a `TIME_FROM` on an edge machine is refused (R165);
  the clock being any node under `/dev` (`/dev/watchdog` passed, R164); a question to an
  address a machine has no way to (R168, R169; accepts A41-A43); an endpoint with several
  spellings (R166, R167); an auditor that took any time its key signed (a floor and a
  ceiling now); a rehearsal that started a responder on somebody's host. And the docs: a
  probe "that convicts every mutant" meant the ones it tries, and now says so.

One finding was this author's own mutant, put in the tree on purpose to see the scene
convict it, and left there at the moment of reading.

A second independent read-only review, of the tree with those fixes, found these; again
each was checked against the code before it was acted on.

- **A way there that nothing writes** (MEDIUM). An EGRESS list that covers the
  authority's address counted as a way even on a link with no GATEWAY, and PID 1
  writes a route to another network only through a gateway (`netcfg.zig`): a till so
  declared was accepted by the court and could never ask. A destination is a way only
  where a gateway carries it (R170; mutant c33), and the refusal's words now say so.
- **A clock that went backwards was said in one order of the file only** (LOW). The
  auditor noticed a later entry dated earlier than an earlier one only when the
  statement about the earlier entry came first in the file; the two orders are one
  claim and are both said now (mutants u30 and u31, and a test with the file reordered).
- **Words that said more than the code.** Item 4 of ruling 07 (a machine with no source
  says its records are ORDERED and UNDATED) held for a machine that runs the record's
  witness, from its second boot on, and for no other: the documents now say who says it.
  "No front and no clock" ignored the emulator's. A witness that gates a commit still
  failed when the file of kept statements could not be read, or the declared key was no
  key, where the rest of its time reading only reports. And the seat's own comments,
  messages and documents still said `head` where a statement names an entry's digest.
- **A scene that did not check its builds.** Its three image builds did not read whether
  they had succeeded before using what they left, so a failed build could have left the
  last run's image to be mistaken for this one's; each is removed first and its status
  read now (NAM-2).

## Named, not closed

- **NTS is not built.** Ruling 07 names two sources for an authority: a battery-backed
  clock declared as hardware, and authenticated network time through a declared
  EGRESS. Only the first exists; a box with `EGRESS none` needs a member of its
  fleet that has a clock, which is built, and a clock of its own, which is a purchase.
- **One authority, and an upper bound.** A fleet has one; a statement says no later
  than and never how long before; and an authority that signs a time earlier than the
  real one makes false statements over true signatures -- that is the trust a fleet
  places in the member it names, and the court cannot judge a clock.
- **The holder of the device's key** can compute its own future lines and ask their time
  early: a statement dates bytes, and the device's signature on them says whose they are.
  Closing it takes a challenge the authority issues and the entry carries, which changes
  the journal's format and is not built.
- **An authority's key cannot be replaced.** A rebuilt card makes a new key, and the
  statements the old key signed are not taken by a fleet that no longer enrols it;
  there is no retirement for an authority as there is for a device (RET-1). The witness
  says so of each of them and does not fail on them; `harb time verify` with the old
  fleet file is how they are audited.
- **The authority answers anyone who asks, as often as they ask, from a process that is
  not confined.** It signs a digest nobody has to have written (that is what a time-stamp
  is: the existence of bytes, never their authorship), costs a signature per datagram, and
  answers a 76-byte question with about 250. It holds the device's key and parses one datagram
  format, in a child of PID 1 given only stdio and its socket. There is no limit, no
  filter and no namespace.
- **PID 1 waits up to six seconds, once, after the verdict.** The feed of the watchdog and
  the health checks resume afterwards.
- **The emulator's clock is a fixed base.** What a board's battery keeps is OS-5's to
  show. (The base is a day in the past: it is the host's own clock being outside the half
  hour the statements are held to that tells an RTC read from a clock that was not.)
- **The tour does not teach it**, and `stranger_walk.sh` does not boot the scene: it
  needs two machines on a wire and the enrolment by hand.

## The law this pays for

**Name what nobody can compute in advance.** A time-stamp proves a value existed. The
journal's own hash was the obvious value and it is made of public things, so an
authority asked about it dated a future the device had not yet written. The digest of
the line the device SIGNED cannot be asked for until the line exists.

**A check that another check also makes is judged by the case only it can see**, and it
happens again each time a neighbour is added: the record's hash check was invisible to
every test that altered an entry with another after it; and once the entry's place was
checked, the chain check was invisible to every cut. A guard shadowed by a neighbour
reports green while doing nothing, and a mutant of it survives until somebody writes the
case that only it can fail.

**A witness that gates a commit does not fail on what is advisory.** The first
`harb journal` exited 1 on a kept statement that did not verify, and that service decides
whether a trial commits: a line a power cut shortened, or a statement signed under a key
since replaced, would have held back every later boot, for a seat whose whole contract is
that an authority that is down costs the machine nothing.

**What a process reads off the wire must not be able to take it down.** PID 1 asks, and
`parseInt`'s leniency was a panic of PID 1 waiting for a datagram with line ends on it.

**A judge you have never seen convict is a claim, and so is a conviction nobody can
repeat.** The scene's pin was said to catch three put-back bugs, from an experiment done
by hand and gone with the afternoon. A second review asked where the script was. It is
five mutants now, each run through the whole scene in a copy of the tree, and it runs in
twenty-three minutes.

---

# OWN-2 — a world asks the kernel what it may write, and the machine's root was open

OWN-1 gave a world a directory and said so. Everything it showed that a
world writes only there was indirect: PID 1's word that it handed the
directory over, the disk's reading of the directory after the boot, and a
probe run outside the machine. No boot had shown a world that is not root
doing the writing -- the first server's application declares no table, so
it leaves no file -- and none had asked the kernel, from inside a world, what
that identity may write. So the witness of the seat is a verb a world runs
as itself, and a machine to run it on.

## What was built

- `harb own <dir> [--not <dir>]...` (`src/own.zig`), the witness of STATE as
  `harb id` is USER's and `harb reach` is EGRESS's. Run as the identity the
  machine gave a world, it makes a file in `<dir>` and reads it back; asks to
  make a file in `<dir>`'s parent and in `/`, which are the machine's, and must
  be refused; and, for each `--not`, a directory another world owns, asks to list
  it and to make a file in it, and must be refused both. Its last line is the
  verdict. It exits 1 when an answer was wrong (unlike `get` and `reach`, whose
  answers are where a machine stands: this asserts an invariant), so PID 1's
  ledger says `exited 1` where the expectation says `exited 0`, and the world
  that comes AFTER never starts.
- `machines/qemu_own.machine`: two worlds, `first` as `alpha` owning
  `/data/alpha` and `second` as `beta` owning `/data/beta`, each running
  `harb own` on its own directory with the other's as `--not`. Nothing but
  `harb` is on the image, so a stranger boots it
  (`experiment/os2_image.sh qemu_own`, and `stranger_walk.sh` does).
- the disk witness of `os2_image.sh` reads what is IN each directory too, as
  the disk names it: `disk: /data/alpha/note -- owned by 2001:2001, mode 0644`.
  What a world said is on the console; what it kept is on the disk.

## What it found, the first time a world was asked

**`/` was writable by every identity.** The first boot said
`own: / -- WROTE A FILE THERE: this world can change the machine's own
directory`. The initial filesystem is a tmpfs when the kernel has `TMPFS`
(every image's does), and a tmpfs's root is mode 1777: until closed, any
identity can make files in `/`. It was true of every machine with a USER since
USR-1, whose entry said an identity "can write only where the machine made a
writable place (`/tmp`, a declared mount)". `/tmp` is root's, mode 0755, and the
root was the open one. The sticky bit kept an identity from deleting what root
put there, so nothing the image carries could be taken; it could still leave a
file where another world, or PID 1, would read it. PID 1 now closes `/` (mode
0755) before anything else, silently when the kernel does it (nothing claims it:
the pinned boot of `qemu_own` is what shows it, from inside a world) and with a
console line when it cannot.

## What judges it

- the pinned boot, **53 lines, identical on two runs**
  (`machines/qemu_own.expected`): both worlds write their own directory, are
  refused in `/data`, in `/`, and in the other's directory (a listing and a file),
  and say `this world wrote in its own directory and nowhere else`; the disk,
  read back, has each `note` owned by its identity and each directory 0700 with
  the disk's root still 0:0; and the same image with no disk behind its mount
  starts neither world.
- **the pin convicts the machine it should**: with the call that closes `/`
  disabled, the same boot says `own: / -- WROTE A FILE THERE` for both worlds, the
  first exits 1, and `second never started -- it comes AFTER first, which exited 1`.
- the act's unit test and a mutant (`experiment/state_probe.sh`: the directory is
  asked about and left as it is, and the mode is read back as 1777).

## Named, not closed

- **The tour does not teach it.** A lesson needs the exactness the tour demands
  of every step (the file, the text, the command, the expected answer and the
  undo) and a renumbering nobody asked for; `qemu_own` is booted by a stranger's
  walk and not yet by a lesson.
- **It asks the questions a world can ask, not every one.** It asks about its
  directory, the directory above, `/`, and the named neighbours. It does not walk
  the image.
- **A directory a machine declares as tmpfs is open too** (a mount's root is
  1777); a world that keeps one can write there. A world that wants none declares
  no `filesystem`, or narrows its sight (`SEES`).

## The law this pays for

**A witness asked from inside the world finds what the declaration and the
machine's own word cannot.** The declaration said a world writes only where it
was handed, PID 1 said it had handed it, the disk agreed, and the root was open.
Nothing that read a file or a transcript could have seen it: only a world, as
that identity, asking the kernel.

---

# OWN-1 — a world owns a place of its own, and the first server stops being root

The first server of the cloud (SRV-2) ran as the machine itself, and two
documents said why: `doc/CLOUD.md` ("the world runs as root") and
`doc/DIVIDEND.md` §5 ("a USER cannot create a path under the image's
root-owned `/run`"). Taken on the author's delegation of 2026-10-05
(STZ-OS-RULING-16) as the first work of the next stretch, because rung 3
puts more worlds on a machine and each would copy the shape of the first.

## The problem was two walls, not one

Every directory of the image is root's, so an identity that is not root can
write nowhere: not its readiness signal, which `harb ready` creates in
`/run`, and not its database, on a disk whose root `mkfs` made root's. USR-1
had named it as a seam ("everything is still owned by root, so an identity
can read what it is given and write only where the machine made a writable
place") and nothing had needed it until a real server did.

## What was decided, and the four ways it was not done

**`STATE`, a clause of a SERVICE: the directories this world owns.** PID 1
makes each before the world starts, gives it to the world's USER, closes it
(mode 0700), reads it back, and says so only then.

- *Not `/run` made writable to everyone.* Any world could then create or
  delete another's READY file: a forged word that something serves.
- *Not the mount's root handed to the identity.* A MOUNT is the machine's
  declaration and a pack may not carry one (PLC-1), so the identity would
  have to be named in a file that cannot see it; and two identities on one
  mount would own one root.
- *Not derived from the READY path.* `/run` is shared by every world, and a
  directory cannot be handed to one of several. SEE-1's own rule applies:
  derive while the declaration already knows, add a clause when it does not,
  and nothing in the declaration said which directories a world owns.
- *Not made in the image.* `gen_init_cpio` can give a directory an owner, and
  that reaches the RAM root and never a disk. PID 1 does one act for both,
  and reads it back at boot, which a file list cannot.

**The court judges where, and who is near** (machine fixtures A30-A35 and
R104-R138, 173/173 from 132/132; pack 35/35 from 30/30): only an identity
owns anything; a plain absolute path of bounded length; strictly inside `/run`
or inside an ext4 or tmpfs mount the world keeps that is not read-only, with
every mount above it kept too, the INNERMOST mount holding it
(`machine.holderOf`, one reading shared with the image); no two overlapping
directories in the whole machine; READY a plain path, a USER world's directly
in a directory it owns and nobody's inside another's; and the floor's IDENTITY
and JOURNAL, in plain paths too, in none (JRN-1: the owner of a directory can
replace what is in it). What a world KEEPS is `Service.keeps`, and the
confinement now asks the same function: the court and the kernel cannot
disagree about what the world was built to see (EGR-3's law). Two rules about
mounts came with it, because the innermost mount is the one a path lies on only
if the outer one is declared first and no two share a mount point.

## What was built

- `STATE` (`src/machine.zig`), `Service.keeps` and `grantsFilesystem`,
  `machine.within`, `plainPath` and `holderOf`; `confine.zig` hides what
  `keeps` says the world does not keep.
- `ownDir`, `handOver` and `prepareState` (`src/init.zig`): walk from `/`
  with `O_NOFOLLOW` on every step (a link anywhere on the way is a refusal: an
  owner given to whatever a link points at is an owner given to somebody
  else's directory), ask of every directory above the last that it be the
  machine's, make what is missing, `fchown`, `fchmod`, `fstat` -- through the
  raw calls -- and refuse anything the kernel does not read back exactly. A
  mount the kernel refused is remembered, and no directory is made on its
  mount point, which is RAM that would hold the world's writes until the power
  goes and say nothing.
- the signal, which a world's directory made PID 1's business: it is read
  WITHOUT following a link and only as a regular file (`signalStat`), and one an
  earlier boot left is taken away before the world exists (`clearSignals`).
- the boot line (`expect.stateLine`, worded once, derived and printed), the
  plan's `-- owns [...]`, and `harb image`'s `state.list`.
- the first server off root: `machines/ringserv.pack` declares `USER appserver`
  and `STATE ["/run/ringserv", "/data/ringserv"]`, signals at
  `/run/ringserv/ready`, and its application names a RELATIVE database, which
  RingServ puts in the directory `--data` names (an absolute one it keeps where
  it was written, so the first version's `--data /data` moved nothing).

## What was measured

- **Outside the machine first** (`experiment/ringserv_nonroot.sh`): the
  pack's own command, as uid 2000, from `/`, with an empty environment, serves
  `/health` and keeps `ringserv.db` with its `-wal` and `-shm` in the one
  directory it was given, all 2000:2000, and the identity made nothing else in
  the places the probe looks (its tree, `/tmp`, `/var/tmp`, `/dev/shm`). The
  probe runs a second time with the server as root and must convict it, or it
  measures nothing: four statements fail. It is not the machine's image, and
  its copy of the application declares a table so that a file exists at all.
- **The acts, on Linux, against mutants** (`experiment/state_probe.sh`): two unit
  tests (the directory; the signal) and ten mutants, each convicted by the test
  named for it. The two that remove the chown need root, because giving a
  directory to the identity that already owns it asks for no privilege, so only
  a root run hands over to a DIFFERENT owner; the probe says when it did not run
  them. **The first run of the first version was red for a real reason**: the
  standard library's `fchown` and `fchmod` on a directory opened without
  `iterate` get EBADF from the kernel, which it calls `unreachable`. Windows
  cannot see it: init is comptime-gated on Linux, and `zig build cross`
  compiles it and says nothing about what it does. (The first account of this
  said a release build would take it for permission. The shipped build is
  ReleaseSafe, where `unreachable` is a panic of PID 1: see the review, below.)
- **Booted, twice, identical** (`experiment/os9_cloud.sh`, 23 to 49 lines): the
  machine says it made the directories and read them back, the server starts as
  `appserver`, serves, and the machine's own judge matches (19 lines). Then the
  witness that is not PID 1's word: the data disk the boot left behind, read with
  `debugfs` after the journal is replayed on a copy and compared with what the
  image derived, says `/data/ringserv` is 2000:2000 mode 0700 and the disk's root
  is 0:0 mode 0755. Then the negative, the same image with no disk behind its
  mount: the kernel refuses the mount, PID 1 says the directory was not given
  and why, no `start` line follows, and the announcement is not made. The
  smallest cloud (`os8_links.sh`, 146 to 148 lines) carries the same server on
  two wires and a till still reaches it.

## What the review found

An independent, read-only agent read the whole uncommitted diff after the boots,
the courts and the probes were green -- about 450,000 tokens and 23 minutes --
and found things none of them could see. Each is verified against the code
before it was acted on; the fix, and the case that now convicts it:

- **A signal was judged by its spelling** (R128-R131, R137, R138). Only STATE
  went through `plainPath`; `READY "/run/s/"` named the directory itself, was
  "inside" it by a byte, and PID 1 read it as ready the moment it had made the
  directory, before the world ran, with the machine's own judge matching because
  it derives from the same string. A `..` slipped READY into a neighbour's
  directory and IDENTITY out of the question that asks whether a world's
  directory holds it. READY, IDENTITY and JOURNAL are plain paths now, of bounded
  length.
- **A signal on a disk was stale-ready from the second boot.** The new rule
  steered a world whose only directory is on a disk to put its signal there, and
  nothing removed one. PID 1 now clears a signal an earlier boot left, for every
  machine (RDY-1 named the trap and left it to scripts). Test, and a mutant.
- **PID 1 followed links in a world's directory**, as root, when it read a
  signal. A world could point its READY at a neighbour's heartbeat and be
  "ready" and "fresh" on it. (It could always forge its own word; the link let
  it borrow another's.) A signal is a regular file read without following a link
  now. Test, and two mutants.
- **A signal below the world's directory** (R132): the image makes every
  directory above a signal as root's, so the world could never create it. READY
  must be directly in a directory the world owns.
- **A mount the world keeps inside one it does not** (R133): MNT-1 detaches an
  unkept mount with `MNT_DETACH`, which takes the mounts inside it along, so the
  directory was accepted, handed over, announced and not in the world's tree. The
  court refuses a STATE there. That `SEES` of such a mount is empty to the world is
  older than this seat and is named below.
- **`fchown` and `fchmod` map EINVAL to `unreachable`**, and EINVAL is what a
  chown answers for an identity the caller's user namespace has no number for,
  which the repository's own rehearsal harness (`unshare -Urpf`) is. The shipped
  build is ReleaseSafe: PID 1 would have panicked where a line was owed. The act
  uses the raw calls and names the kernel's answer.
- **`holderOf` ignored the order mounts are made in** (R134, R135), implicit
  mounts had no refusal (R136), and nothing bounded a name (R137, R138).
- **Directories above the last were never checked.** One left on a disk by an
  earlier identity would let that identity swap the new directory for its own.
  Every directory above the last must be the machine's (root's, and not open to
  others unless sticky).
- **Claims stronger than the evidence**, each corrected where it stood: a
  refusal "at the pack's own line" (an overlap with the machine's own service
  landed on the machine's line: the court now reports the later claim, and
  PR27, PR28 hold it); "a trial holds" (a world that does not start is never
  ready, so the boot is never judged and a trial is never committed; nothing
  rolls it back either); "a release build would take it for permission"; "an
  identity can write only where it was handed" (a tmpfs mount's root is 1777); a
  probe that said "convicted four ways" while the negative control was a scratch
  copy that nothing kept (it is the probe's second run now); and a stale DIVIDEND
  example that R122 refuses.
- Nits: the witness compares the disk with what the image derived and fails
  loudly without `debugfs` or when `e2fsck` cannot replay; `state.list` is
  printed; `ownDir`'s refused-mount check is wider than the court's innermost
  holder (it can refuse more, never less) and says so.

## What did not work, kept because it says something

**A table in the application's startup.** The first version of the app
declared one so that a database FILE would exist for the witness. RingServ
waits 2000 ms for a worker to come up and then refuses to serve, and creating
the table took longer than that under QEMU's software emulation: `no worker came
up after 2000 ms`, five restarts, no verdict. Booted again as ROOT with the same
app, it failed the same way, so it is the emulator and the server's own wait and
not the identity; and it is a margin, which is a defect in a pin. The
application declares no table, the file is made by the first write, and the
witness is the directory instead. The measurement is in the app's comment, and
the 2000 ms is RingServ's to know (routed to Central).

## Named, not closed

- **A directory two worlds share.** Each world's directory is closed to the
  other, so the model world and the desk of `site/secure-design.html` cannot meet
  on an exchange disk; the page says so now. A hand-over between worlds is a
  fixture-first widening of its own.
- **What is inside.** PID 1 gives the directory away, not what a previous boot
  put in it: change an identity's number and the old files are the old number's.
  A recursive chown at every boot would be surprising and slow.
- **Nested mounts under `SEES`.** A mount inside an unkept mount is detached with
  it (MNT-1's `MNT_DETACH`), so a world that names only the inner one sees it
  empty. The court refuses a STATE there and nothing refuses the `SEES`.
- **No `/tmp` for an identity.** The image's `/tmp` is root's, mode 0755, so a
  world that is not root has no temporary directory. SQLite spills to one only
  for large temporary results, and RingServ served without it; the first world
  that needs one declares it as STATE.
- **The directory is closed when it is handed over.** A restart does not hand it
  over again, and its owner can change its mode.
- **Ports below 1024.** An identity cannot bind them. The front of rung 3
  listens on 443, and giving it that one capability, or the port, is the first
  thing it will have to declare.
- **The boot of a real card.** The directory read back on a real Pi, on a real
  ext4, is OS-5's.

## The law this pays for

**A world that is not root owns exactly the directories it names, and the
machine says so only after the kernel has read each one back.** And:
**the question that decides is what the kernel says**, not what the code asked
(the `iterate` flag, the raw calls); **a test that can only be run where it is not
written is not run until somebody runs it there**; and **a rule that compares
spellings is a rule about the spelling**: every path the court compares is a
plain one, or a second spelling of the same file gets past it.

---

# WDG-1 — a world holds nothing of PID 1's but its stdio, starting with the watchdog

A defect in the floor, found by reading `src/init.zig` for what a server world
inherits (the survey SRV-2 made) and closed by one flag. Small to fix and
worth writing down, because nothing in any boot could have seen it.

## The defect

PID 1 opened `/dev/watchdog` with `.{ .ACCMODE = .WRONLY }` and no
close-on-exec. It does that before it spawns its first world, a world is a fork
and an exec (`spawn`), and an exec keeps every descriptor that is not
close-on-exec. So on a machine that updates A/B (`makeen_box`, on the board)
EVERY world started with PID 1's watchdog open and writable. What a world could
do with it needed no call the floor refuses (SYS-1's deny list names the calls
that change the machine, and an inherited descriptor needs none):

- write to it, and keep the hardware fed while PID 1 has stopped feeding it
  because a world went stale -- HLT-1's rollback, the whole reason the
  watchdog is armed, would never come;
- or write the magic `V` and close it, on a driver that honours that, and
  disarm it for good.

## Why no boot could see it

The emulator never arms the watchdog: QEMU's raspi4b resets the board the moment
it is opened, so its boot line says `harb.watchdog=off` and PID 1 does not open
it. The only machine that arms one is `makeen_box` on a real Pi, and that is
OS-5, parked. Every pinned transcript was green over the defect and would have
stayed green.

## The change, and the audit behind it

`watchdog_flags` (write-only, close-on-exec) and `openWatchdog`, which the one
call site uses. The audit asked what ELSE PID 1 holds across a spawn that is not
stdio, and found nothing: Zig's own `Dir.openFile` and `createFile` set
close-on-exec (`std/fs/Dir.zig`) and PID 1 closes what it opens; the gate pipe of
`spawn` is plain `pipe()`, but the child closes the write end and the read end
by hand and PID 1 closes the write end in `release` before the next spawn; the
names servers' sockets are closed in PID 1 after the fork. The watchdog was the
one.

## The witness

Two unit tests beside the code:

- *the watchdog's open flags are close-on-exec*: the declaration, true on every host;
- *a world that execs holds no watchdog descriptor*: the question that decides
  (MNT-1). It opens a device through the production `openWatchdog`, runs
  `ls -l /proc/self/fd` as a child, and requires the device to be absent from the
  child's table. The same descriptor opened WITHOUT the flag must be present, or
  the question tells nothing apart.

The second can only be asked on Linux, so `zig build test` on the Windows host
passes the first and SKIPS the second (74 passed, 1 skipped there, by design).
`experiment/watchdog_probe.sh` runs both on Linux and then runs them against two
scratch mutants, each of which must be convicted by the test named for it:

- *the flag constant loses CLOEXEC*: both tests fail;
- *the open ignores the constant*: the declaration test STAYS green and only the
  exec test fails. This is the original defect (the call site never passed the
  flag), and it is the one that matters: a guard that reads the declaration does
  not judge the act.

Probed: the production source passes, both mutants are convicted for the right
reason, 17 seconds.

## Named, not closed

- **No sweep.** A descriptor added to PID 1 tomorrow without close-on-exec leaks
  the same way, and this witness covers the watchdog only. A `close_range` before
  every exec in `spawn` would make "a world holds nothing but its stdio"
  structural. It is a change to the start of every world and was not asked for.
- **A world can open the device itself** on a machine where PID 1 holds none (no
  SLOTS, or the emulator's `harb.watchdog=off`): `/dev` is visible to a world,
  opening arms the watchdog, nobody feeds it, and the box resets -- a reboot by
  proxy that the deny list, which names `reboot`, does not cover. Read from the
  driver's behaviour; no boot has shown it. Where PID 1 holds the device the
  watchdog core lets one process hold it at a time, so the world is refused.
- **The board.** Whether the descriptor is gone from a world on a real Pi is
  OS-5's to observe; here it is the kernel's flag and a Linux child that say so.

## The law this pays for

**A world holds nothing of PID 1's but its stdio**, and **a guard that reads the
declaration does not judge the act**: the flags constant was true and the open
ignored it, and only the question "what does an exec'd child hold?" could tell.

---

# FWD-1 — a machine says it is the way between links, and a fleet says it was meant

Rung 2 of the cloud ladder (`doc/CLOUD.md`), taken on the author's "after
that do rung 2" (2026-10-04), after SRV-2 and in the same day. It is the
first rung whose judge is a set of machines and not one: a till on one
link reaches a server on another, through a box that is the way between
them, and a fleet file says the box was meant to be.

## What exists now

- **`FORWARD yes`** on a hosted machine with at least two links
  (`src/machine.zig`; machine fixtures A27-A29 and R95-R103, **132/132**):
  PID 1 switches the kernel's own forwarding on once every network is up
  and says so only after READING THE SWITCH BACK (CON-1's rule). It is a
  plan step, so `harb plan`, the derived expectation and PID 1 read one
  list. `machines/qemu_forward.machine`: two networks, FORWARD, one
  witness, pinned at 18 lines.
- **The image gives one emulated NIC per LINK**, in declaration order, and
  refuses in words a machine whose interfaces are not numbered the way the
  kernel numbers them (eth0, eth1, ...). A loopback is declared and is no NIC.
- **The server of names and addresses** (`src/names.zig`): a box that
  forwards offers itself as the ROUTER (option 3) to everyone it serves, and
  answers for the FULL names on the other links it serves. A bare word is a
  name on THIS link: the same word on the far link is another device.
- **`harb get <host> <port> [path]`** (`src/get.zig`): a world asks a server
  one question and says what came back. `names.lookup` is the one reading of
  `/etc/resolv.conf`, shared by `ask` and `get`, so the two cannot disagree
  about where a name goes (`ask`'s output is byte-identical: the names pair
  matched its 68-line pin unchanged).
- **Fleet v0.2** (`src/fleet.zig`): `LINKS` where `LINK` named one wire, and
  the `ROUTE` kind. **60/60**, 24 of them new (FA7-FA11, FR27-FR49).
- **The smallest cloud**: `machines/cloud_front.machine` (the box),
  `cloud_till.machine`, `cloud_core.machine` (RingServ placed on it by the
  pack of SRV-2, with an application that listens where another machine can
  ask), `cloud_links.fleet`, and `experiment/os8_links.sh`, which boots the
  three on two wires. Pinned at **146 lines**, identical on two runs and
  then judged against its pin.

## The result, in the transcript's own words

```
till: ask commons.core.cloud -- 10.20.0.2 (from 192.168.20.1)
till: get http://commons.core.cloud:8210/health -- 200
    {"code":0,"message":"OK","data":{"up":true}}
```

A device that was told nothing but its own address learned the router, the
resolver and the name of its link from the box that serves it, asked for a
server on ANOTHER link by its full name, and connected to it through the box.
RingServ, on the core link, answered. The same till then asks for a bare
`commons` and for `www.example.com` and is told, correctly, that neither
exists on this network.

## The decisions that mattered

**FORWARD is one switch for the whole machine, not a list.** The kernel
decides whether to forward by the interface a packet ARRIVES on, and not by
the one it leaves from, so `FORWARD [front, core]` on a machine with a third
network would name a perimeter nothing keeps: a packet from front could still
leave by the third. A per-network clause would be a claim the machine cannot
make. So the clause is `yes`, the machine forwards among ALL its networks,
the boot line says "between front and core" and says "nothing here filters
it", and the fleet (below) is where "which links, through whom" is said.

**A forwarder is a door, and the fleet must have said it was meant.** A
machine that says FORWARD joins every one of its links whether or not anybody
meant it to. FR39: a forwarder no route goes through. FR40: a forwarder some
pair of whose links no route through it joins. This is the check no machine
can fail: the box is right to forward, the till is right to ask, and the set
is wrong if nobody agreed.

**A route is a way both ways, and everyone on a joined link takes it.** No
packet filter exists to make a route one-way, and an answer needs a way back
as much as a question needs a way there. So a member of a joined link has a
gateway that IS the way (FR42-FR44), or is told the way by a lease from the
one machine that can offer it, the link's own server (FR45), and does not say
there is none (FR46), and its perimeter reaches the other links (FR47). A till
whose route is right and a server with no way back are each faultless alone.
A destination that is a declared link no route joins is a route to nowhere
(FR48). One wire has one prefix (FR41).

**Names follow the way, never the other way round.** The server answers for
the far link's names only when its own machine forwards. The alternative, a
fleet-level "answer these names", would have let "a name that resolves and a
way that is closed" be declared; as built, it cannot. The cost is honest: the
closed round of the boot shows the box's SILENCE about the far link, and no
round shows a packet dropped by a box that forwards nothing.

**The router option, not static gateways.** The lease already carries a router
(`netcfg.zig` has always read it), and a client's own EGRESS is its perimeter:
the till writes one route, to the core's prefix, through the router it was
told, and no default route. A box that forwards offers itself as the router to
everyone it serves, and the box that does not still sends none (a box that
named itself the way out without being one would lie to every device on the
link).

**The servers promise the way only once the kernel has said there is one.**
The first version started each link's server as its network came up, with the
router and the far names taken from the DECLARATION, and read the switch back
afterwards. If the switch had failed, leases would still have named the box the
router and the resolver would still have answered `commons.core.cloud`: the name
that resolves over a closed way that this entry says cannot be declared, and
CON-1's rule (a line says where the machine is only after asking) broken by the
line beside it. Found by the independent review below, not by a boot. A machine
that forwards now starts its servers AFTER the forward step, with the router and
the far names only if the switch read back as on and only for the links that are
up; a box whose switch failed still serves each link its own names, says why,
and its boot differs from its expectation. A machine that does not forward is
unchanged, line for line (the names pair matched its pin).

**A loopback is not a link.** SRV-2 made the machine declare its loopback so a
readiness probe could ask 127.0.0.1; this rung found four judges that count
networks and needed the same answer: FORWARD's "two networks", the image's NICs
(a loopback is no NIC), the guarantee sheet (SRV-2's own fix) and the names
server's other links. `machine.isLoopback` and `countLinks` are ONE reading,
and the sheet's private copy was deleted. R100 holds it: one wire and a
loopback is one link.

**`EGRESS none` is refused on a machine that forwards (R101).** The line it
prints, "the machine knows no way off its own link", is EGR-2's lie: a
forwarder is a way off every link it joins.

## Probed, and what the boots found

- **Three rounds**, the second and third are what make the first mean
  something: the declared till crosses; the same till with a hardware address
  nobody declared gets no lease and so no router and no resolver -- which is
  the register's reach and no more: it does NOT stop a device that chose its
  own address and set the box as its gateway, because forwarding filters
  nothing; the same set with a box less its one clause is silent about the
  far link and the till reaches nothing.
- **A margin, not a fixture (BDG-1, again).** The first run of the script
  started the till as soon as the core said `ready`; the till finished within
  the core's ten-second health window, the script killed the core, and the
  core's own verdict ("the boot matches its expectation") never reached the
  transcript. It would have been present on a slower emulator. The script now
  waits for the core's own judge line, which is what "serving, and proven so"
  is.
- **The closed round found a bad message.** The till declares a route through a
  router the lease never named, and the kernel refused it as "no such device",
  which says nothing of the cause. `netcfg` now says "no way written: this
  network has no gateway, and a route to another network goes through one".
  Nothing pinned before carried the old words.
- **The fleet court convicted its own author three times.** The first run of
  the widening was 40/58: a fixture machine named `core` beside a network named
  `core` is one namespace twice, and eighteen cases refused for a reason that
  was not theirs. Renamed, 56/58: the two left (FR44, FR45) each tripped an
  EARLIER rule that was true (a forwarder on a link is itself a member that
  must take the other route; a server of a joined link is itself a member that
  must declare its gateway). The cases were rewritten so the refusal is the
  rule they are named for. A court that refuses for the wrong reason is not a
  court of that rule.
- **The tour convicted a scoreboard.** Lesson 3 quotes `zig build court`'s
  counts, and `learn --check` refused them at every widening (127, 130, then 131
  and 58). `site/threats.html` carried the machine court's count too.
- **FA7 is the real set, verbatim**: `machines/cloud_links.fleet` and the three
  machine files it names, taken mechanically by the fixture generator, so the
  court judges what the boot boots.
- **An independent read-only review found six things, and every one held up
  against the code.** A fresh agent with no stake in the design read the diff
  after the commit and could not run anything. (1) Two links with overlapping
  prefixes were accepted by both courts, and no packet could use the way: now
  FR49. (2) The servers announced the way before the switch was read back
  (above). (3) Two links of one machine could answer to the same DOMAIN, so the
  far one could never be asked for by its full name: now R103. (4) FR47 asked a
  single destination to swallow the other link's whole prefix, which refused the
  least-privilege perimeter (`10.20.0.2/32`, the one server) and printed a
  member's host address as if it were the link's prefix: the test is now
  whether the perimeter TOUCHES the other link, FA11 holds a /32 each, and the
  message prints the link's own prefix. (5) One over-claim of mine: "a box that
  now forwards admits no more devices than before" is true of leases and names
  and false of the way, since forwarding filters nothing and a device that chose
  its own address and set the box as its gateway would be carried; the three
  places that said it now say what is true. (6) The emulator's NIC order was
  observed on `qemu_pc` and was assumed for `qemu_virt`'s memory-mapped NICs:
  a machine of several links is now imaged only where the order has been seen.
  The commit that carried the work had passed every gate I own; none of the six
  was a failing test, which is what a review is for.
- **The repository's own warning about inline programs was ignored once more**:
  a Zig test appended through a heredoc lost one backslash of every multi-line
  string, and the compiler caught it. The edit tool and a scratchpad file are
  the fix this file already names.
- **A regression run that read a stale log.** The first batch of regression
  boots passed `os2_image.sh qemu_forward` as ONE argument, bash answered 127 in
  two seconds, and the loop printed the previous run's `JUDGED: ... matches`
  line from a log nothing had rewritten. The exit code and the seconds sat
  beside it and gave it away. The batch was re-run with the arguments split and
  the logs removed first; the three entries without arguments had run for real.

## Named, not closed

- **Transit.** A route joins links on ONE machine. The chain front, box, core,
  box, far is not declared, and a link with two ways on it is refused (FR44):
  a member has one gateway.
- **A way that is one-way**, and a forwarder that filters. Both need the packet
  filter of rung 6; this rung's boot line says "nothing here filters it" because
  it is true.
- **A forwarder's own hardware addresses.** A member declares one `HARDWARE`
  and a box on two links has two NICs; the emulator gives them its defaults and
  no declaration can yet say them.
- **The server is reached over plain HTTP.** RingServ refuses to bind an address
  a network can reach without `:behindproxy`, which is an acknowledgement and
  checks nothing (`machines/ringserv/app_core.ring` says so). Until rung 3's
  front exists it is the application's word, and what is TRUE is the extent the
  boot shows: reachable from the front link through the box, and from nowhere
  else.
- **Being admitted to a lease is not being admitted to the way.** The register
  decides who is given an address, a router and a resolver; it does not decide
  who is carried. A device that chose its own address and set the box as its
  gateway reaches the core, because forwarding filters nothing. That is rung 6's
  packet filter, and the boot line says so.
- **The emulator's NIC order is known for `qemu_pc` only.** `qemu_virt`'s
  virtio-net-device sits on a memory-mapped bus; a machine of several links is
  refused there in words until somebody observes the order.
- **A stranger cannot boot it**: the server is built by a PowerShell script from
  RingServ's source, so `stranger_walk.sh` does not walk this boot, and the tour
  teaches neither `FORWARD`, `ROUTE` nor `get` (their words are not in
  `learn.words`). A stranger can run `harb fleet machines/cloud_links.fleet`,
  `harb plan` and `harb check`, which need nothing.
- **`machine.stzu` lags further.** The language's declaration in stz's own
  format is already 13 clauses behind (HF-31, ringpp's finding); `FORWARD`,
  `LINKS` and `ROUTE` widen it, and it is that desk's to bring up.
- **Lease renewal, IPv6, a DNS referral, a pool**: still not built, still by
  design or by seam as NAM-1 named them.

## The law this pays for

**A set of machines is judged by what its members do to each other**, and the
checks that matter are the ones a single machine cannot fail: the door nobody
declared, the way there with no way back, the route to nowhere. And **a claim
about reach is the sentence the boot prints, so it says what the kernel keeps
and nothing more**: "between front and core", "and nothing here filters it".

---

# SRV-2 — a real server is a world on the floor: RingServ, placed and booted

Rung 1 of the cloud ladder (`doc/CLOUD.md`) has two halves. PLC-1 built
the one that needed nobody else, the pack and `harb place`. This is the
other, a real server as a world, and it waited for the author to name
the server: "RingServ (future HaroServ)", 2026-10-04, with rung 2 after
it. The server the ladder was written around, RestoLean's Commons, is
that desk's to hand over, so **RingServ stands in for it here, as the
Luau worlds stand in for the box's** (SRV-1), and its application says so
in its first lines. One session.

## What exists now

- **`harb ready`** (`src/ready.zig`), a verb of the one binary: the
  program a world runs when its server answers a URL and writes no file.
  It starts the server, asks the URL on a rhythm, creates the READY path
  while the answer is a 200, and leaves the path to age when the answer
  is anything else. The floor's own measuring does the rest: SRV-1 sees
  the path appear, HLT-1 reads its age against the window.
- **`machines/qemu_cloud.machine`**, a member of a cloud, the machine a
  pack is placed on. It grants what a server world asks (network,
  filesystem, process, threads, clock), declares one mount for the data
  and its own loopback, and carries no service.
- **`machines/ringserv.pack`**: the one SERVICE RingServ needs, with each
  need and the place it was read in the pack's own header.
- **`machines/ringserv.stage`** and two variables of `experiment/os2_image.sh`
  (`HARB_MACHINE_FILE`, `HARB_STAGE`): the placed machine is a file
  `harb place` wrote, and the image carries two files no machine names,
  the server and the application, listed in one place. Neither variable
  is set for a machine that was already here.
- **`experiment/os9_cloud.sh`** places, images, boots and judges, and its
  exit is the judge's (VDCT-1); **`experiment/ringserv_build.ps1`** builds
  the pinned source.
- **`machines/qemu_cloud_ringserv.expected`**: 23 lines. The machine
  judges its own boot against the 18 that PID 1 says, and the pin judges
  all 23, the server's own banner among them.

## What the server asks, and where each need was read

Read at RingServ's origin/main, `002ba21` (2026-08-29), through git
objects only: its working tree holds the uncommitted work of its own desk
and was neither read nor touched (CENTRAL-READONLYPIN-01). Then built
from a clean checkout of that ref, run under WSL and measured.

- **a listening socket**, on 127.0.0.1 unless told otherwise (`:host`);
- **a store**: SQLite, in the directory it is given with `--data`;
- **threads**: 38 at four workers, so a TASKS ceiling written from "a
  handful" would have refused its own server (the pack says 64, at two
  workers);
- **memory**: 73 MB resident at rest, so 128;
- **a clock**, no environment, no dynamic loading: one static x86-64 ELF,
  24.3 MB, with no interpreter;
- **a readiness that is not a file**: `GET /health` answers
  `{"up":true}`, and nothing is written anywhere.

## The two things the floor could not do for it

**It cannot say that it is serving.** The floor's READY is a path a
daemon creates. Three ways to close that, one chosen:

- *a shell loop in the world* -- refused: RUN refuses a shell by name,
  and the image has none;
- *PID 1 asks the URL* -- refused: it would put an HTTP client in the init
  and make "ready" two readings, a path for one world and a URL for
  another, that have to agree (EGR-3's trap, one layer over);
- *a program in the world* -- chosen. `harb ready` is the readiness probe
  every other supervisor has, with the one difference that the floor
  already measures the word, so it is said in the floor's own language
  and PID 1 did not change. When RingServ grows a `--ready-file` of its
  own the pack changes one line and the verb is unused, which is why it is
  a verb and not a part of PID 1.

**It cannot be asked a question on a machine whose network is nothing.**
The probe asks 127.0.0.1, and the floor builds only what a declaration
asks for (BDG-1), so `lo` is down until a NETWORK says it is up. A world
that NEEDS the network shares the machine's, so the machine declares the
loopback, and says why in its first lines.

## The declaration that made a promise false

Declaring the loopback broke the sheet that judges the four standing
promises. `harb guarantees` took the first NETWORK a machine declares to
be the one the box is found by, so a machine whose ONLY network was `lo`
read "always reachable: KEPT, `boot: network loopback -- lo up`" -- a
promise made to whoever needs the box, kept by an interface nothing
outside the box can reach. EGR-2 again: a sentence worded for a wire and
printed for an interface that goes nowhere, in the direction that
reassures. Found by running the sheet over the new machine before
writing a word about it.

The sheet now skips a loopback when it asks which network the box is
found by and which address the phones learn, and says so when it is the
only one. The placed machine reads **1 of 4 promised, 1 kept** (the
durable log; the other three said "not promised", with why). Two tests
sit beside the code: a machine whose only network is `lo` promises
nothing to anyone outside it; a machine on a wire keeps both, with or
without a loopback beside it. **A declaration that adds a SPECIES of
something the judges count is a new question for every judge that counted
the kind** -- THR-1's grep, once more.

## Pinned by source, because the binary is not the same twice

The kernel is pinned by the digest of its tarball, and the first plan was
the same for the server: build it, digest it, refuse a different build.
Two builds of one ref in two folders differ by 160 bytes (24,313,280 and
24,313,440), so a digest of the binary would convict an honest rebuild.
In one fixed folder the digest repeats, and the build script uses it. What
is pinned is the SOURCE ref; the digest is printed for the record.
`vendor/PIN.md` says so, and says that changing the ref changes the
pinned boot in the same commit, because the transcript quotes the
server's banner.

## The boot, and its negative

`os9_cloud.sh` places the pack, images the result, boots it under QEMU
and judges it against the pin. Between the `start` line and `ready` the
pin carries the server's own banner, `serving on
http://127.0.0.1:8210/api/v1  (2 workers)`, because a world's stdout is
the console and a fixture is what the machine said. Two boots,
byte-identical after normalisation.

**The negative, run once and not pinned** (a failing boot is not a
fixture; this one was read): the same machine and the same server with
`harb ready` told to ask a port nothing listens on. The server starts and
speaks. The machine never says `ready`, never judges, and the emulator
ends at its timeout. Against the pinned boot the transcript lacks exactly
the five lines from `ready` on, besides the port the probe changed. A
server that is alive and does not answer is not serving, and the machine
says so by not saying it is.

## Probed

- **The adapter, outside the floor, on seven questions, before any
  boot** (WSL, scratch folders): the path appears when `/health` answers
  and its mtime moves while the answers continue; SIGTERM to the adapter
  reaches the server, which exits 143, and so does the adapter, leaving
  the path where it was; a program that never answers leaves no path and
  the adapter ends with it; a program that cannot start ends with 127 and
  a sentence; a program that dies by itself ends with its own status; a
  command line without `--` or without its two arguments is refused in
  words; a server that answers 404 on the URL is up and not serving what
  was asked, so there is no path.
- **The probe found a bug before any boot did.** An unstartable program
  returned 1 and said nothing: Zig 0.15's `Child.spawn` does not report a
  failed exec, and the verdict arrives only at `waitForSpawn()`. Four ways
  to fail to start are probed now (a missing absolute path, a bare name
  off PATH, a file that is not executable, a directory), each 127 with the
  reason in words.
- **A readiness is judged by what CONSUMES it** (PRJ-2): the adapter was
  proven outside the floor first, and only the boot shows PID 1 seeing
  the path it makes, which is why the probe's answers were not the end.
  The probe is what caught the silent exit.
- **The regressions** -- `qemu_egress` against its pin, and the guarantee
  sheet of `makeen_box` against its pin -- are unchanged by the loopback
  fix and by the two variables of the image script.

## Named, not closed

- **The world runs as root**, inside the floor's closed deny list and its
  cgroup. A world with a USER cannot create a path in `/run`, which the
  image makes root's (`dir /run 0755 0 0`), so a placed server that
  should not be root needs its READY path somewhere it can write, and no
  clause says where.
- **READY is a first-boot fact.** `signalled_ready` is set once and never
  cleared (`pollReady`, `src/init.zig`), so a restarted server is not
  waited for again and no line says it is serving again. HEALTH, which
  reads the path's age, is what answers for it, and the adapter does not
  delete the path when its child dies, for that reason.
- **`/health` does not enter the server's VM** (RingServ's own
  `docs/FUSION.md` gives 0.18 ms), so a worker wedged in the VM would
  not be seen by the probe. That is the server's to grow; the probe asks
  whatever URL it is told.
- **A world has no port of its own.** NEEDS network gives the machine's
  whole network, so two packs asking for 8210 are judged fine and
  collide at boot. Per-world reach is rung 6; a PORT is no clause today.
- **The stage list is a script's.** `HARB_STAGE` is read by `os2_image.sh`,
  so what a placement carries beside its programs is a convention of a
  shell script and not a part of the pack. A pack that names the files its
  programs are is the cleaner seat, and it is another clause.
- **A stranger cannot boot this yet**: the server is built by a PowerShell
  script from RingServ's source, so `stranger_walk.sh` does not walk it
  and the tour does not teach `ready` or `place` (their words are not in
  `learn.words`). A stranger can rehearse a placement, which needs
  nothing; the boot needs RingServ built first.
- **The binary is not reproducible across folders**, so nobody else can
  check a digest of "the" RingServ. A released static binary with a
  digest is the ask that retires this, and it is already routed.

## The law this pays for

**Ready is what a question returned**, and the question is the world's to
ask: a server that says nothing is probed, a probe that gets no 200
leaves no path, and PID 1 keeps one reading of ready. And **a
declaration that adds a species of something the judges count is a new
question for every one of them** -- the interface that goes nowhere read
as a way to be found.

---

# PLC-1 — a pack asks, and the machine grants

Rung 1 of the cloud ladder (`doc/CLOUD.md`) is the Commons as the first
declared server world, and its first half needs nobody else: the
solution's services written apart from any machine, and placed on one.
Taken on the author's "go" (2026-10-04), in one session.

## What exists now

- **The pack**: a third file of the machine language, judged by the kinds
  it may carry -- SERVICE and USER -- as the fleet file is (FLT-1's rule
  again). `src/pack.zig`, `declarative/pack/{GRAMMAR,PINNING}.md` and
  `fixtures.json`.
- **`harb place <machine> <pack>... [--out <file>]`**: judges the machine
  alone, reads each pack, composes ONE machine text, hands it to the one
  court, and reports a refusal at the file and the line that wrote it.
  Without `--out` it is a rehearsal. The written file is a machine like
  any other: `check`, `plan`, `image` and `judge` take it, and `plan`
  was seen to start the pack's service as its own identity, seeing only
  the mount it named.
- **The pack court**: `harb court --pack`, the third court in `zig build
  court`: **30/30**, 6 accepts and 24 rejects, pinned.

## The decision that mattered: one reading of the rules

A pack's SERVICE has `NEEDS`, and a need is granted by a CAPABILITY that
lives in a machine, so a pack cannot be judged alone: the code map found
that `machine.declare` is the only place the service rules run, and that
a file of services and users is refused there as "exactly one MACHINE
(found 0)". Two ways out. A second copy of the rules for packs would be
a reading that has to agree with the first -- EGR-3's trap, one layer
over. The other: compose the machine file and the packs into one text
and hand it to the court that already exists (PRJ-2: a generated
artifact is judged by what CONSUMES it). That is what `place` does, and
it is why the pack alone is judged only for what a pack IS (its kinds,
its names) and why no rule of the machine court was copied.

Two consequences that cost thought. A refusal from the composed text
counts lines in a text nobody wrote, so `place` keeps where each file's
lines sit and says `commons.pack (line 9)`; the one rule that embeds
ANOTHER line number in its message (R7, the one namespace) would have
named a line of the composed text, so the names are checked in pack
terms first, kind-blind as R7 is, and the refusal names the file and
line that took the name. And the machine is judged alone first, so a
refusal that arrives with the placement is known to come from it.

## It contradicted the plan's own document

`doc/CLOUD.md` said, in §6 and an hour old, "no second grammar ... never
a third file". The plan the author approved named a pack file. The code
map by the session's reader made the contradiction plain (a pack is a
third file TYPE of one language, never a second grammar), and CLOUD.md is
amended beside the sentence, dated, not rewritten.

## Probed

- **Twelve mutations, each in a scratch copy of the sources and never the
  working tree**, each judged by the unit tests and by the court in fresh
  processes, after the unmutated copy was seen green on both: the kinds
  open to everything; a fleet kind refused as a machine kind; the names
  blind to the machine and to earlier packs; blind inside one pack; a
  pack of identities alone accepted; the machine's own refusal not said
  to come first; a line counted from the file's start minus one; the
  last line of a file not the file's; no note that a refusal in the
  machine's own lines came with the placement; the banner naming the
  digest of something else; a path written with backslashes keeping its
  directories; a machine file with no final newline running into the
  banner. **12 of 12 caught**, each by the case or the test named for
  its rule, five of them by the unit tests alone because the court does
  not read a banner's digest or a path's separator.
- **The first run of the court was green at once, which is when a court
  deserves doubt.** Reading the verdicts, not the count, found one case
  wrong: PR24 carried a fragment that was a guess and a line that was
  the wrong quote (the language reports an unterminated string at the
  line of the quote that never closes). It was rewritten so its meaning
  is plain, and every other `line` was checked against its source.
- **A branch no case reaches** -- a refusal landing in the machine's own
  lines after the machine passed alone -- exists for rules not yet
  written. It is judged beside the code, through the pure functions that
  map a line and word a refusal, so the first such rule does not mislead.
- **The prober repeated DOC-3's lesson.** It looked for `FAIL` straight
  after a test's `...`, and Zig prints a failed assertion there and
  `FAIL` on a later line: every unit detector read as "crashed" until it
  read what follows the `...`. The verdicts were right; the labels were
  not.
- **And the repository's own warning was ignored once and cost three
  minutes.** The fixture generator was patched by a program written
  inline in a shell argument; its `\n` became real newlines and the file
  no longer parsed. The scratchpad file and the edit tool were the fix,
  as CLAUDE.md says to reach for first.

`zig build -j2`, `test`, `court` (machine 120/120, fleet 32/32, pack
30/30, the tour, the pages) and `cross`, each with `-j2` and one at a
time: green. Not run: the WSL boot judges, which nothing here touches --
no image, no machine file with a pin and no boot changed.

## Named, not closed

- **A solution's own declaration does not project into a pack.** The
  projection stzp's server target would make is not written; packs are
  hand-written, and the real Commons has not been placed on anything.
- **A service has no port and no reach of its own**, so a pack cannot
  say either: a world has the machine's network when it NEEDS it, and
  reach is per NETWORK until it is per world (CLOUD.md, rung 6).
- **A fleet does not name packs.** `MEMBER ... PACKS` is fleet v0.2, with
  the routes of rung 2; today `harb place` is run by hand.
- **The tour does not teach `place`, and "a pack" is not one of its
  words** (`learn.words`, which README and `site/words.html` carry
  verbatim). When a lesson uses it, the word joins the three places at
  once.
- **A pack's own digest is recorded, not the programs it names**; staging
  them is `harb image`'s, as for any machine.

## The law this pays for

**A pack asks, and the machine grants**, and a second file of the same
language is judged by ONE reading of the rules, never a copy of them that
has to agree. And **a refusal that names a line in a text the reader did
not write is not an answer**: it is said at the file and the line that
wrote it.

---

# DOC-3 — a code block is what the page renders, not a line that begins with three backticks

`harb docs --check` (DOC-1) knew a fence by one test: a line that, its
leading spaces trimmed, BEGAN with three backticks. A fence inside a
quote begins with `>`, so the judge never opened it, and neither of its
rules -- the width, the machine shown in full -- ever read what was
inside. WHATS-NEXT.md, which Central writes for this desk, carried its
refresh command as one line inside a quote: 106 characters, where a page
allows 64. It stood for 11 commits, from f31dd8e (2026-09-28 02:51) to
6ade3a0 (2026-09-29 00:44), and the court was green over every one. It
was found by reading, while committing Central's wrap of that very line:
the wrapped block measured 44, and the question was why the unwrapped
one had ever passed.

EGR-3's lesson, one layer over: a guard that recognises a claim by how it
is SPELLED is narrower than one that asks what it COVERS. The claim is
that no code block on a page scrolls sideways, and a code block is
whatever GitHub draws as one.

## What a quote costs, measured

A block inside a quote has less room, and how much less is a fact about
GitHub's page, so it was measured there and not reasoned (LRN-3): the
rendered WHATS-NEXT.md, in the browser pane, the window set to 820 and
then to 1280 pixels wide.

| window | page body | the quote's code container | taken by the quote |
|---|---|---|---|
| 820 | 707 px | 671 px | 36 px |
| 1280 | 846 px | 810 px | 36 px |

An unquoted block's container is the page body itself (the README at
1280: 823 of 823 pixels). GitHub draws a quote with 16 pixels of padding
on each side and a 4-pixel border -- 36 pixels at both widths, which is
4.81 characters of the code font as this machine draws it (7.48 pixels a
character, 13.6-pixel text). So a quote costs a fixed number of
characters, not a share of the column. `quote_cost` is 5, rounded up, so
the 4-character margin that puts 64 under the author's 68 survives
inside a quote: 59 inside one quote, 54 inside two.

One trap on the way: GitHub shrinks a code block to its longest line, so
the block's own width said 44 -- the width of what it held. The room is
the width of the element that holds the block.

## What the judge reads now

- **A fence is three or more backticks or tildes**, after any number of
  quote markers (`` > ``` ``, `` > > ``` `` and `` >> ``` `` alike), and
  a backtick fence whose words hold a backtick is inline code, not a
  fence -- CommonMark, which GitHub renders.
- **A block closes on its own kind**: the same character, at least as
  many, and nothing after. Before, any line beginning with three
  backticks toggled the block, so a four-backtick block ended at the
  first three, and a `~~~` block was never a block at all.
- **A quote's end is its block's end.** GitHub closes a code block when
  the quote around it closes, so a line with fewer markers ends the
  block and is read again as itself -- it may open the next one.
- **A page's end closes a block**, and a machine in a block the page
  never closed is judged like any other.
- **A line inside a quote is measured without its markers, against the
  room the quote leaves**: `WHATS-NEXT.md:20 -- a code line 106 wide
  inside a quote; GitHub shows 59 there before the block scrolls`.
- **The court says how many blocks sit inside a quote** -- one today --
  so a reader of the verdict sees that the new reach is live rather than
  assuming it.

Before any of it was written, the pages were surveyed for the shapes
that would now be judged differently: no indented fence, no fence of
four or more backticks, no closing fence with words after it, and one
quoted block. Over every other page the verdict is unchanged -- 21
Markdown files, 3 machines in full, 23 words -- and the new judge was
run over the tree to see that it is.

## Probed

- **The real page, both judges** (a clean worktree of HEAD): WHATS-NEXT.md
  as it stood at 87f6da4, judged by the binary from before this change,
  green; by the binary after it, one conviction, at line 20; and the
  page as it is now, by the binary after it, green, with the quoted
  block counted.
- **Seven mutations, each in a scratch copy of the source and never the
  working tree**: quotes never taken off a line; a quote that costs
  nothing; the line that ends a quote never read again; any fence
  closing any block; a page's end never closing a block; three backticks
  around words taken as a fence; quote markers read inside an unquoted
  block. Each was caught by the test named for its rule, and no other
  test moved. A mutation whose text did not occur exactly once was
  refused before anything ran, so a typo could not pass as an acquittal.
- **The prober's first reading was wrong, and the tests were right.** It
  looked for `...FAIL`, and Zig 0.15 prints a failed assertion straight
  after the `...`: all seven mutations were red, and all seven were
  reported as not compiling. A verdict must be RECEIVED (NAM-2); the
  prober now reads the status each test line ends with.

`zig build test`, `court` (120/120, 32/32, the pages, the tour) and
`cross`, each with `-j2` and one at a time: green.

## A number corrected, beside its commit

6ade3a0's message says the old line "was 104". It was 106 after the
quote marker, 108 as written. 104 was an estimate, carried into a commit
as though it had been measured. The commit is pushed and stays as it is;
this is the correction, and every number in this entry was measured.

## Named, not closed

- **A list's room was not measured.** A block inside a list is measured
  as written, its indent counted as characters; GitHub pads a list, and
  no page here has a block in one. Measure it before one is written.
- **The cost was measured with this machine's code font.** A wider font
  loses fewer characters to the same 36 pixels, so 5 holds wherever the
  font is at least as wide as this one; a narrower one was not seen.
- **68 is the author's screen, on the README.** A file's own page on
  GitHub is wider at the same window (846 against 823 pixels at 1280),
  so the rule is a little stricter there than it needs to be -- the safe
  side.

## The law this pays for

**A code block is what the page RENDERS, never a line that begins with
three backticks.** The judge asked how a fence is spelled at the start
of a line; a reader sees whatever GitHub draws. And **a number carried
from an estimate is not a measurement**: it reads the same in a commit
message, and it was two characters wrong.

## Amended 2026-09-30: the page it was found in is not the repository's

Everything above stands as it was written. What changed is which files
the judge reads. The page this entry was found in, WHATS-NEXT.md, and
the `.central/` folder are Central's files for this desk: the
coordinating session writes them into this working copy. They were
tracked here from f31dd8e (2026-09-28) on, in a repository that had
been public since 2026-09-27; they carry absolute paths on one machine
and the estate's own coordination. On 2026-09-30 the author asked
whether publishing them was an infraction, and they do not belong in a
public repository: they are untracked and ignored now, and
STZ-OS-RULING-13 in `doc/PROVENANCE.md` records the ruling and what it
left alone.

The judge walks the FOLDER, not git, so untracked files in the working
copy would still have been judged: a wide line in a page the repository
does not hold turns the court red on this machine and never in a clean
clone. Two skips, both in `collect`, both held by
`Central's files are not judged, and a page of the same name elsewhere
is`: `.central` joins the folders never entered, and the ROOT's
WHATS-NEXT.md is not collected. Only the root's -- a WHATS-NEXT.md in a
folder is somebody's own page, and the test says so.

- **The count moved from 21 Markdown files to 18**, and the three that
  left are Central's. Measured two ways: the judge says 18, an
  independent walk with the judge's own skip rules says 18, and so does
  the index.
- **Five mutations, each in a scratch copy of the source and never the
  working tree**, after the unmutated copy was seen green (a mutation
  proves nothing over a baseline that is red): `.central` dropped from
  the folders; the file check never true; the file check matching at
  any depth; `collect` never asking it; the file check matching any name
  that ends in `NEXT.md`. Each was caught by the one new test.

**Named, not closed.** The judge still answers "what is in this
folder", and the claim it serves is "what the repository holds". Where
the two differ -- a file that is untracked and NOT ignored, or ignored
and not Central's -- the folder wins. Asking git closes it, at the cost
of needing git where `harb docs --check` runs, and a stranger's copy of
the tour may have none. Left open until a file that is not Central's
shows the gap.

---

# CON-1 — a console is where the kernel speaks, and PID 1 asks it

LRN-3 found it by running a BREAK IT: a machine's `CONSOLE` was
declared, announced and judged, and never acted on. The kernel's
console came from a board table in `src/image.zig`, and PID 1 only SAID
the declaration. `qemu_egress` with `CONSOLE "/dev/ttyS3"` booted with
`console=ttyS0`, printed `boot: console /dev/ttyS3`, and went on
narrating on ttyS0. And the lie was not hypothetical: the flagship's
pinned transcript said `boot: console /dev/ttyS1` in every emulated
boot, while QEMU booted it with `console=ttyAMA0`.

## The question that decides

Two honest shapes were on the table: (a) the boot line follows CONSOLE,
or (b) the grammar refuses a CONSOLE the board does not use. Which one
is possible turns on something physical -- can the emulator LISTEN
wherever a machine declares it speaks? `experiment/console_probe.sh`
booted images that were already built, changing only `console=` and
which QEMU serial port feeds stdio:

| boot line | QEMU listens on | heard |
|---|---|---|
| PC, `console=ttyS0` | serial 0 (as today) | 18 boot lines |
| PC, `console=ttyS3` | serial 0 | nothing |
| PC, `console=ttyS3` | serial 3 only | 18 boot lines |
| Pi, `console=ttyAMA0` | the PL011 (as today) | 27 boot lines |
| Pi, `console=ttyS1,115200` | the PL011 | nothing |
| Pi, `console=ttyS1,115200` | the mini-UART only | two bytes, `bb` |

A PC's four serial ports are real in both worlds, so a declaration can
choose among them and the emulator can follow it. The Pi cannot be
followed: QEMU's raspi4b models a mini-UART, and Linux's driver stalls
on it after two bytes. The board's console is a port the emulator
cannot carry -- a lack, like its watchdog and its missing NIC.

## Why (a)

- **(b) would not have fixed the lie that was live.** The Pi's only
  port on the pins is ttyS1 under either rule; the flagship's emulator
  would have gone on announcing it while speaking on the PL011.
- **(b) would turn CONSOLE into a restatement.** One legal value per
  board is a value BOARD already fixes, and SEE-1 says derive what the
  declaration already knows; a clause is for what it does not.
- **(a) carries information where the hardware offers a choice**, and
  the probe showed the whole chain holding for the PC's fourth port.

## What was built

- **The consoles a board HAS** (`machine.boardConsoles`): the PC's
  `/dev/ttyS0`..`ttyS3`, the ARM emulator's `/dev/ttyAMA0`, the Pi's
  `/dev/ttyS1` (its PL011 goes to Bluetooth). A hosted CONSOLE names one
  of them or nothing -- the kernel's own `/dev/console`, which is the
  board's first. Fixture-first: A25, A26, R91-R94; the court's first
  run on them was 116/120, the four refusals accepted by the code as it
  stood.
- **Both boot lines follow the declaration.** The card's `cmdline.txt`
  names the port. The emulator's line names it too, and routes QEMU so
  that every serial port before it goes nowhere and it is stdio: the
  emulator hears the declared port and no other. For the first port the
  line is what it always was, byte for byte.
- **The Pi's emulator speaks on the PL011, and its lens says so**
  (`Lens.console`). The build's list of the emulator's lacks now has
  three lines.
- **PID 1 asks the kernel.** `TIOCGDEV` on its own standard output --
  `/dev/console` -- returns the real tty's number; PID 1 names it
  (`machine.consoleDevice`, from the kernel's device numbering) and says
  the declared line only when the two agree. Otherwise it says both:
  `boot: console /dev/ttyS1 -- declared, and the kernel speaks on
  /dev/ttyAMA0`. Under the Pi emulator's lens that line is the lack; on
  a card it is a boot that differs from its file, and a trial holds.
- **`harb judge --lens emulator` asks the board's lens** in `image.zig`
  instead of keeping its own copy (HDW-1). The copy lacked the console
  and would have judged the emulator by a lens nobody else used.

## Every machine, booted

Every image's PID 1 changed, so every pinned machine was booted:
`qemu_hello` (35), `qemu_budget` (39), `qemu_confine` (65),
`qemu_egress` (20), `qemu_identity` (48), `fleet_temoin` (51), the fleet
arc (43), the two machines on one wire (68) and `makeen_qemu` (27)
match their pins unchanged -- the kernel named the declared port, so
PID 1 said what it always said. The four promises match theirs (39).
The WSL rehearsal is unchanged: `/dev/console` names no port, and
nothing is asked.

`makeen_box` differed, and the diff was read before it was pinned (SYS-1):
line 2 and the `steady:` boot's line 2 now say the emulator speaks on
the PL011, and the `unmet:` trial -- judged by the BOARD's expectation
-- counts three lacks where it counted two, naming the console pair.
129 lines to 131, matched again on a second boot. Lessons 17 and 18
quote the new counts; `learn --check` refused them until they did.

The BREAK IT now in lesson 4 was run before it was written: with
`CONSOLE "/dev/ttyS3"` the boot line said `console=ttyS3`, QEMU was
given three `-serial null` and `-serial mon:stdio`, the whole boot was
heard, and PID 1 said `boot: console /dev/ttyS3` because the kernel
did. `CONSOLE "/dev/ttyS4"` is refused, naming the four ports.

## Named, not closed

- **The card's witness is unobserved until OS-5.** On a Pi the kernel
  should report the mini-UART as `/dev/ttyS1` (major 4, minor 65); no
  board has booted this code.
- **An edge or touch CONSOLE is the substrate's, and nothing here reads
  it** -- `harb project` does not carry it to MicroRing. Declared and not
  acted on in this repository, and now said so in the grammar.

## The law this pays for

**A line that says where the machine is, is said only after asking.**
A restatement of the declaration cannot be wrong about the declaration,
and so it is never a witness to the machine. And **when a lack is
physical, find it before choosing a shape**: one probe showed that one
board could follow the declaration and the other could not, and the
choice followed from that, not from taste.

---

# LRN-3 — the tour, walked by a stranger

Found while fixing the README's "Try it" (DOC-1): stz is private, and the
tour's boots in lessons 4, 5, 6, 10 and 17 ran Luau worlds under `stzr`.
Queued as a seat of its own, because a lesson that moves is a BREAK IT
that must be run again.

## The premise was wrong, twice

The queued task said a stranger's `qemu_hello` "boots but judges itself
different from its pin", and the README said the same -- written in the
DOC-1 seat from that premise, and never run. So before anything moved,
`experiment/stranger_walk.sh` was written to find out. It copies what
this repository publishes (`git ls-files`, tracked and not ignored) into
`$HOME/harb-stranger` -- no zig-out, no stz build, no kernel; the tarball
is seeded to spare 142 MB and then verified by the fetch like any
download -- builds `harb` with the pinned Linux zig, and walks the tour's
boots. A stranger's `qemu_hello`, in under a second, exit 1:

```
stzr NOT staged (no build of stz under
    zig-out/stz-x86_64-linux-musl)
image: refused -- service hello: program /stzr is not staged
    under zig-out/image/qemu_hello/root
derive refused
```

Nothing boots. `harb image` refuses a machine whose program is not
staged, before any kernel is built -- the right answer, NS-1's shape (a
machine is never built short of what it declares), and not the one
anybody had written down. `qemu_budget` (lesson 10) and `makeen_box`
(lesson 17) the same, naming `modest` and `kds`.

And lesson 18, which boots nothing: `judge_guarantees.sh` reads the
expectation `harb image` derives, and it was written AFTER the staging
checks. The refusal took it along; the report said "the board's
expectation is not built ... run experiment/os2_image.sh makeen_box
first", and that advice led straight back to the refusal. `JUDGED: FAIL`,
for a lesson that needs no runtime at all.

## What was done

**Lessons 4, 5 and 6 boot `qemu_egress`**, which runs only `harb`: the
boot narrating and judging itself survives the move, and lesson 11 now
says it is the same machine. Every BREAK IT was run before it was
written:

- **Lesson 4's old step was false on every machine.** It promised "The
  boot goes SILENT" when CONSOLE says `/dev/ttyS3`. Run on `qemu_egress`,
  PID 1 announced `boot: console /dev/ttyS3` and went on narrating on the
  emulator's console: the boot line's console comes from the BOARD table
  (`console_qemu`), and CONSOLE is announced, never acted on --
  `qemu_hello` included. Replaced by a step that is true: move the
  `denied` witness to `1.1.1.1`, and the narration follows (`boot: start
  denied -- pid N -- /harb reach 1.1.1.1`, `reach 1.1.1.1 -- no route`)
  while the pin refuses exactly those two lines. The CONSOLE seam is
  named here and not fixed: a machine announcing a console it is not
  speaking on is NS-1's worse case, and whether the boot line should
  follow CONSOLE or the grammar refuse one the board does not use is a
  decision of its own.
- **Lesson 5 teaches more on this machine.** 14 lines to 17, not 16 to
  18, and the third is one the reader never wrote: `boot: confine --
  extra has no network of its own`. A world that asked for `process` and
  not `network` got walls around a network, a part of the kernel this
  machine had never switched on -- the derived fragment gains exactly
  `CONFIG_NAMESPACES=y` and `CONFIG_NET_NS=y`, so the kernel is built
  again (`kernel cache: MISS`, about three minutes). The lesson says so.
- **Lesson 6:** one character of the pin's line 2, and `JUDGED: FAIL`
  with a one-line diff while the machine's own judge still matches.
  Exactly as promised.

**Lessons 10 and 17 stay** -- the budget's memory kill and the
flagship's cards are Luau worlds -- **and say so before their RUN**,
derived and never written per lesson. `needs_runtime` in `src/learn.zig`
names each machine with a world under `/stzr` and its first such world;
the note quotes the refusal from `image.unstaged_fmt`, the constant
`harb image` prints; and it tells the reader that every line the lesson
quotes is in `machines/<name>.expected`. Lesson 10's BREAK IT adds how to
see the edit without the runtime: `harb plan` prints the new ceiling.

**`--check` holds all of it:** the table against the machine files (a
machine that gains or loses a Luau world, or whose first one is renamed,
turns the court red), and every quotation of a lesson carrying the note
against THAT machine's pin -- a narrower claim than "some pin holds it".
Probed with three planted mistakes in one fresh build (a wrong first
world, a machine missing from the table, a lesson quoting another
machine's pin): three convictions, each named, exit 1.

**The first boot says once what it needs** (derived: whichever lesson
boots first): `zig build cross -j2` and the kernel fetch, with QEMU and
a kernel toolchain in WSL.

**`harb image` writes the expectation beside `image.env`**, before the
staging checks, and keeps its place in the image's file list: a clean
`qemu_egress` boot matched its pin line for line after the change.
**`os2_image.sh`'s `stzr NOT staged` says who needs it** -- every
stranger saw that line on every boot, the ten that need nothing
included. The README's sentence is corrected.

## Walked from a stranger's copy of the working tree

| lessons | what a stranger runs | what happened |
|---|---|---|
| 4-6, 11 | `os2_image.sh qemu_egress` | boots; its pin matches (20 lines) |
| 7-9 | `os2_image.sh qemu_confine` | boots; matches (65 lines) |
| 10 | `os2_image.sh qemu_budget` | refused, as the note says |
| 12-13 | `os2_image.sh qemu_identity` | boots twice; matches (48 lines) |
| 14 | `os7_fleet.sh` | the arc matches (43 lines) |
| 15 | `os6_names.sh` | two machines, one wire; matches (68 lines) |
| 17 | `os2_image.sh makeen_box` | refused, as the note says; the expectation stays |
| 18 | `judge_guarantees.sh` | matches its pin (39 lines); it was FAIL |

Lessons 1-3 and 16 boot nothing and need only the binary.

## The law this pays for

**What a reader WITHOUT something sees is observed by taking it away,
never reasoned.** Two sentences said a stranger's boot would run and
judge itself different; neither was run, and the machine does something
better and different. **A text derived from the declaration alone is
written before anything that can refuse**, or the refusal takes it along
and a judge's advice leads back to the refusal. **A BREAK IT is run
again whenever it moves** -- which is how a false one is found.

---

# DOC-2 — a word is explained by what it does, and worded once

The author, 2026-09-27, four things in one message: the AI facet belongs
at the front of the project, on GitHub and on the site, "since Harobanda
is the better possible OS solution for governed agents, right?"; "what it
mounts" should say what it means, disks, "keep in mind the educational
dimension of any project we make around the Softanza Project"; cryptic
phrases like "this binary as PID 1" should be explained where they stand;
and "judges" should be tied to the practical thing, because "not anyone
has the ability to get the link between a metaphoric concept and the
practical thing of a technology".

## What was found

**Metaphors explained by metaphors.** The site's word page said "the
court: the judge of the grammar". The tour's glossary said PID 1 "mounts,
it starts the worlds, it reaps them". A reader who does not already know
what a PID, a mount or a reap is learned nothing from either. And the two
lists disagreed: eight words on the site, eleven in the tour, worded
differently on purpose (PEDAGOGY finding 6, whose reason was a Windows
path).

**The facet to be pushed forward held claims stronger than the code.**
Reading them before moving them:

1. `agents.html`, "The data cannot leave". `EGRESS` writes routes: the
   machine knows no way out, which EGR-1 says is not the same as being
   prevented. There is no firewall behind it.
2. `agents.html`, "Every act is recorded ... an agent's actions are
   auditable". The journal records BOOTS -- what the machine was and what
   it judged of itself (JRN-1). What a world does is the world's record,
   and nothing records it today. `assistant.html` ("every exchange is
   recorded") and `field.html` ("every action recorded") said the same.
3. `agents.html`, "It rehearses first ... on a virtual twin", and "an
   agent can draft a change" as a present fact. The twin is stzlib's and
   does not read this machine's file yet; the agent's half of the
   proposal loop is not built. The check and the trial are.
4. `enterprise.html`, "bit-for-bit reproducible". No build script fixes
   the kernel's build timestamp, so two builds of one file differ. The
   claim is gone; the seam is named here.
5. The refusal quoted on `agents.html` and `running.html` ("needs the
   network, which nothing here grants") was not the machine's words:
   `alerts needs network, which no declaration grants`.
6. `ship.html`, "`harb` writes it" to the device -- beside a paragraph
   saying the tooling prints that command and never runs it.

One claim is in pixels: diagram 3, hand-drawn outside this repository,
labels the assistant's envelope "every exchange recorded". Its page and
alt text were left describing the image, the page's prose was corrected,
and the image is the author's to redraw.

> **Amended 2026-09-28.** The author asked for diagram 3 without "every
> exchange recorded", and it was drawn again in the house style
> (`site/diagrams/diagram3.py`, a PNG at both widths). Drawing it showed
> the count above was wrong: it was not the one claim left outside the
> prose. Diagram 8 still said `bit-for-bit` (point 4) and diagram 10
> `every action recorded` (point 2) -- both drawn by scripts in this
> repository -- and the `<meta name="description">` of `assistant.html`
> and `agents.html`, the line a search result prints under the page's
> name, still said "every exchange recorded" and "every act recorded".
> The reading above read what each page says in its body. A claim is
> wherever a reader meets it: the prose, the picture, its alt text, and
> the snippet a search engine shows before anyone opens the page. All
> five now say what their pages say.
>
> A sixth was in prose, on the author's word the same day: `promises.html`
> told the administrator a fleet is "reproducible", which reads as point 4
> in one word. It now says the files are versioned, diffable, and the
> source every box is built from.
>
> The phone variant of diagram 3 had also been published with two labels
> wider than their boxes -- "internet — a cloud model, a ver", cut at both
> edges -- because `narrowlib` never asked `house.fit`, which the wide
> drawings had always been held to. It now asks it of every label it does
> not wrap, and refused the old narrow 3 (exit 1) before it was fixed; the
> other nine narrow drawings re-rendered byte for byte.

## What was done

**One plain vocabulary.** `learn.words` rewritten, eleven words to
twenty-three, each saying what the thing does: a machine, a declaration,
a clause, a service, a capability, to mount, the kernel, to judge, the
court, the plan, an image, QEMU, PID 1, the transcript, a pin, a world,
the envelope, the floor, EGRESS, a trial, the watchdog, a fleet, a seat.
Where the project's word IS a metaphor (the court, a world, the floor, a
pin), the definition says so and then says the plain thing. Checked
against the code while written: "a world sees none of the other
programs" was drafted and cut, because a world that declares `process`
shares the machine's process table; the watchdog is also released when a
service that promised to keep answering goes quiet (HLT-1), not only on
a bad trial.

**Worded once, carried three times.** The README's "The words, in plain
terms" and `site/words.html` were generated from the source, and `harb
docs --check` gained a third rule: every word of the tour, in its order
and in its words, on both pages -- backticks, bold and `<code>` are not
differences, a changed word is. Unit test: carried, changed, missing,
reordered, each convicted where it should be.

**The agents, in front.** A lead under the README's tagline and a
section, "Built for governed AI agents": a whole box for an office
assistant that the court accepts -- no network, one disk, 2 GiB and two
cores -- a table of what each line means and WHAT enforces it (the
kernel, its control groups, its filter, or the image, where the shell was
never put), the proposal loop with its unbuilt half said, why the
operating system rather than only a sandbox, and what is real today for
agents. On the site: the hero line, a section after "What just
happened", the AI card first in "ways in", "AI & agents" second in every
page's nav, and the six claims above corrected to what is built.

**Plain words where they stand.** "What it mounts" became which disks it
uses and in which folder each appears; "this binary as PID 1" became the
first program the kernel starts; "judged" is now, wherever it first does
work, "checked against what must be, and the difference said"; the
image, the kernel, QEMU, the watchdog, LTS and a digest are each said
once in plain words where they are first used. Every page's footer links
to the words.

## On the author's question

Is it "the better possible OS solution for governed agents"? The pages
do not say "best", by the rule this repository already keeps: a claim is
what can be checked, and "best" is a comparison nobody has run. They say
what is specific and checked instead -- the limits are the kernel's,
derived from one file a reviewer can read, proven by reference boots, and
there is no shell or installer to go around them -- and they say what is
not built.

## The law this pays for

**A word is explained by what it DOES, never by another metaphor.** A
reader who does not already know the practical thing cannot get it from
a figure of speech, and the reader a project most needs is that one.
**A vocabulary is worded once**, and every page that lists it carries it
verbatim under a judge. And **the moment a claim is pushed to the front
is the moment to read it again**: the facet the author wanted in front
held six sentences the code did not back.

---

# DOC-1 — what a page shows is a claim, and a stranger's path through it is the judge

The author, 2026-09-27, with a screenshot of the README's own "Try it"
block scrolling sideways: no code zone on a GitHub page with a horizontal
scrollbar; and the README does not introduce the project simply, nor
explain its rationale and its practical value -- take inspiration from
the site.

## What was measured

GitHub showed 68 characters of a README code line on the author's screen
before the block scrolled. The rule is 64, a margin under that. Measured
before anything moved: 152 code lines wider than 64 in 10 of the
repository's 17 Markdown files, 98 of them in this one, whose transcripts
quote a boot event as one line however long its sentence is.

## The check

`harb docs --check` (`src/docs.zig`), which `zig build court` runs beside
`learn --check`:

1. no fenced code line in any Markdown file is wider than 64 characters
   -- characters, not bytes, so a line of arrows is measured as it looks;
2. every machine a page shows IN FULL -- a block with `DEFINE MACHINE`
   and no `...` -- is one the court accepts, by the same
   `machine.declare` that `harb check` runs: Markdown fences, and the
   site's `<pre>` blocks with their markup removed.

Its first run found only widths, because the second rule's findings had
been caught by hand the same day: the README's headline example ("a
whole machine, in nine lines") and the site's home page were both
REFUSED -- `PROFILE` is required -- and the assistant page's excerpt
showed a daemon that signals READY and never says it restarts. The first
thing a visitor read was a claim no judge had ever read. The check is
what makes the next one fail in the commit that writes it, and it names
the line of the PAGE, where the reader can go and look.

Not judged, and named rather than implied: an excerpt (what is elided
cannot be judged, which is why a page says "in full"); code indented
rather than fenced; and transcript QUOTES in pages. LRN-2 checks the
tour's, but this file quotes boots of machines that have changed since,
and is right to.

Probed with seven mutations, each in a scratch copy of the pages and
never the working tree: a code line of 65 convicted at its page line and
one of 64 acquitted; the README's machine without `PROFILE`, the site
home page's without `PROFILE`, and the README's service without a
`RATIONALE`, each convicted at the page line the court names; and the
assistant excerpt losing `RESTART`, acquitted, because an excerpt is not
judged. A unit-test expectation broken on purpose failed (41/42), which
is how it is known the new tests run at all.

## How a wide line was wrapped

A transcript line continues on the next with four more spaces of indent
-- the tour's own convention, so a reader sees one line of output. A
command takes its comment on the line above, and a long one continues
with its shell's own continuation (`\` in bash, a backtick in
PowerShell), so it still pastes as one command. A `RATIONALE` continues
inside its quotes: the grammar folds a continuation's indent to one
space (C6 3.2), so the wrapped string IS the same string. The
architecture's pipeline was redrawn top to bottom. No quoted word
changed.

## What following the README as a stranger found

The README's "Try it" ended with `bash experiment/os2_image.sh
qemu_hello`. Walked with only what a stranger has -- a fresh clone:

1. **No cross build.** The script stages
   `zig-out/cross/x86_64-linux-musl/harb`, which only `zig build cross`
   makes. The README said `zig build`.
2. **No kernel.** `vendor/linux/` is gitignored, and the script's first
   act on the kernel is to read `vendor/linux/PIN.txt`.
3. **The fetch took the newest kernel, not the pinned one.**
   `os2_kernel_fetch.sh` took "the newest 6.12 point release" from
   kernel.org and wrote whatever it took into `PIN.txt` -- on any day
   after the pin, a different kernel from the one every transcript here
   was judged on, re-pinned without a word. It also extracted 1.4 GB
   beside the tarball that nothing ever read: on a Windows mount, the
   thing this repository's own notes forbid. It now takes exactly the
   tarball `vendor/PIN.md` names, refuses unless kernel.org's digest and
   the pin agree, and extracts nothing. `experiment/kernel_fetch_probe.sh`
   judges it both ways, each verdict requiring the exit code AND the
   reason: the pin fetched and verified, and a wrong digest, a version
   kernel.org never released and a tarball on disk that is not the
   pinned one, each refused for its own reason. 5/5. (A probe of the
   probe -- the fetch with its comparison disabled -- was not run.)
4. **stz is private.** `qemu_hello` runs its world under `stzr`, built
   from the stz repository, which a stranger cannot clone. The boot
   would run, print `stzr NOT staged`, and judge itself different from
   its pin -- correctly, and to the one reader who could not know why.
   *Amended 2026-09-27 (LRN-3): it does not boot at all. `harb image`
   refuses a machine whose program is not staged, before any kernel is
   built. The sentence above was reasoned from the queued task, not run;
   a stranger's copy (`experiment/stranger_walk.sh`) showed the refusal.*

So the README now boots `qemu_egress`, which runs only `harb`, needs
nothing outside this repository, and shows a promise worth the minutes:
the kernel knows a way to the one declared destination and none to
8.8.8.8. Booted end to end after the change: kernel cache HIT, the boot
judged itself, and the transcript matched its pin line for line (20
lines, exit 0). The README lists the packages a first boot needs and
says which machines need the private runtime.

The site's home page had the same flaw in a worse form. Its terminal
showed `harb boot hello.machine` -- a verb that does not exist --
printing lines no machine has ever said. It now shows the two real
commands and the machine's own words.

Five lessons of the tour boot `stzr` machines too (4, 5, 6, the budget
lesson, the flagship). Reworking a judged lesson means running every
BREAK IT again, so it is queued as its own seat, not folded in here.

## The law this pays for

**What a page SHOWS is a claim about the system, so it is judged like
one**: a code line the reader has to scroll sideways to read, and a
machine the court would refuse, fail the court in the commit that wrote
them. **And an instruction is judged by walking it with only what a
stranger has** -- a fresh clone, no private repository, no kernel
already fetched. Every step the author's own machine had taken for them
long ago was a step the README did not say.

---

# EGR-3 — everywhere has one spelling, and the check asks what a list covers

The author delegated what waited on him (2026-09-27: "do what waits on me
on my behalf"). One row was EGR-2's open question: should the grammar
REFUSE the explicit spelling of an unrestricted reach? Ruled yes
(STZ-OS-RULING-06), and ruling it found a live defect.

## The defect ruling it found

EGR-2 fixed what the BOOT said about `EGRESS ["0.0.0.0/0"]` by looking for
a destination whose prefix is 0. Reading that code to implement the
ruling: `EGRESS ["0.0.0.0/1", "128.0.0.0/1"]` has no prefix of 0, so the
boot printed `0.0.0.0/1, 128.0.0.0/1 and nowhere else: no default route`
while the two routes between them reach every address, 8.8.8.8 included.
EGR-2's lie, spelled in two pieces. The guard asked how the claim was
SPELLED; the claim is about what the list COVERS.

## The rule

A list of destinations is a perimeter. `machine.coversEverything` asks
whether the NETWORKS a list names -- not the addresses as written, so
`10.0.0.0/0` is every address -- together span the whole space, by
extending the covered prefix of the space until nothing extends it. The
grammar refuses such a list, however it is spelled; everywhere already
has a spelling, which is to declare no EGRESS at all. And `egressLine`
asks the SAME function: a boot line is never the place a coverage rule is
re-derived, and two readings that must agree are two readings that will
not.

Fixtures: A24 (half the space, `0.0.0.0/1`, is still a perimeter --
accepted, which is what proves the check is not over-eager), R88
(`0.0.0.0/0`), R89 (the two halves), R90 (`10.0.0.0/0`). 114/114; one
unit test holds seven lists, three that cover and four that do not.

## The lesson, rewritten from its own run

Lesson 11's BREAK IT had the reader paste `EGRESS ["0.0.0.0/0"]` and boot.
Under the ruling that line never boots, so the step is now `harb check`,
and the lesson was rewritten from what it printed when RUN -- in
PowerShell, the reader's shell, exactly as the lesson prints the command,
after Git Bash had eaten the backslash in `machines\qemu_egress.machine`
on the first attempt. Both spellings: the same sentence, the same line
(35), exit 1. The third experiment -- deleting EGRESS, the spelling that
IS allowed -- was booted too: no `boot: egress` line, the network line
grows its gateway, 8.8.8.8 is reachable, and the pin refuses the
transcript, which the lesson now says in its own words.

That last sentence tripped a census: a unit test counts the lessons whose
BREAK IT boots an edited machine, because those get a DERIVED warning
that the pin will refuse them (LRN-1). It expected six and found five.
The per-lesson assertion -- the warning fires exactly when a reader would
see `JUDGED: FAIL` -- held for every lesson; only the census moved,
because lesson 11's step is a check now. The count is a tripwire, it
tripped, somebody looked, and the reason is written beside it.

## Probed before it was believed

Five mutations in fresh builds, each red for its own reason, and each
naming what must NOT go red -- the part that proves precision:

| mutation | convicts | and not |
|---|---|---|
| the old rule (a single prefix of 0) | R89 | R88, R90 |
| the refusal removed | R88, R89, R90 | |
| an over-eager check (every list is everywhere) | A24, A18 | |
| the address as written, not its network (court) | R90 | R88, R89 |
| the same, in the unit test | the coverage test | |

## Also done on the delegation, recorded here because they are acts

- **The rename is booted everywhere it touched.** The six pins RET-1
  left open all matched unchanged: `qemu_budget` (39 lines),
  `qemu_confine` (65), `qemu_egress` (20), `names` (68, two machines),
  `makeen_qemu` (27), `makeen_box` (129). The rename's text edits were
  consistent wherever the rename had not already been found broken.
- **The card is rebuilt.** `makeen_box`'s boot rebuilt the SD image, so
  its boot line reads `harb.slot=A rdinit=/harb`: step 2 of the OS-5
  plan is done. Step 3 stands -- `card` should REFUSE a stale card, so
  that the trap cannot come back when a person forgets.
- **The mirror** (STZ-OS-RULING-04) was uploaded and then judged by a
  restore: every file back OK, the two tarballs identical to the digests
  git pins.

## The doctrine

**A check that asks how a claim is SPELLED is narrower than one that
asks what it COVERS** (EGR-3): EGR-2 recognised "everywhere" by a prefix
of 0, and the same claim in two pieces walked past it, with the boot
announcing a perimeter over it. When a guard recognises a claim by its
shape, find the claim's other shapes -- or ask the question the claim is
ABOUT.

---

# RET-1 — a key a device used to have, trusted through one entry; and what the first real run found

The author's word, 2026-09-26: plan the Raspberry task for later and
advance on other fronts. OS-5 was parked with its order written into
CLAUDE.md. Of the seams DIVIDEND §14 lists as unordered, revocation was
taken: it is this repository's own ground (the fleet, the journal, the
identity), it waits on no hardware and no ruling, and a customer pulls
it -- when the Makeen box's card dies, the rebuilt card makes a new key,
and every record the old card signed stops being checkable.

## The design, and why it needs no clock

A retired key cannot simply stay trusted. The need is a card that DIED;
the danger is a card that was STOLEN, which goes on signing with the
same key. A date would separate before from after, and this floor has no
trusted clock (JRN-1 left the journal without timestamps on purpose).

The chain needs none. Every entry's hash covers its `prev`, so ONE hash
fixes every entry before it. `DEFINE RETIREMENT` names a member, the key
it held, and the hash of the last entry the fleet verified -- `THROUGH`
-- and the key is trusted through that entry and not one further.
Whoever holds the old card can keep signing, but only by EXTENDING the
chain, and `journal.verifyThrough` refuses an extension by position,
however perfectly it chains. A record that never REACHES the head is
refused too, even when every entry verifies: a shorter record the device
wrote and a different chain the key's holder wrote since both verify,
and nothing but the head tells them apart.

A declaration of its own, not a clause on the member, because every
declaration says why it is there, and why a key was retired -- a failed
card, a missing one -- is what an auditor will need years later. And
"retirement" rather than "revocation": revocation promises the key is
dead; what the fleet can say is exactly how far it is still trusted.

**The head is printed by the verifier, and only after the chain
verifies.** Until now nothing printed it at all, so an operator would
have copied it out of the raw file -- and a head copied from a file
nobody checked is a head somebody else may have chosen.

## Three things found while building it, each a guard narrower than its claim

**The machine file refused the fleet's kinds by NAMING them**:
`d.kind == .FLEET or d.kind == .MEMBER`. RETIREMENT added to the shared
enum would have walked straight past -- and the probe showed how: a
machine file carrying a RETIREMENT was not refused for a wrong reason, it
was ACCEPTED. THR-1's trap exactly. It is now one exhaustive switch,
`belongsToFleet`, which both parsers ask; a kind added after it does not
compile until somebody says which file carries it. No machine fixture
had ever judged the refusal the fleet grammar claimed; R85-R87 do now.

**FR5 compared keys as TEXT.** "A key that appears twice attributes one
device's records to two" -- and `aa..` beside `AA..`, one key, passed as
two, because hex is case-blind and a string comparison is not. The
retirement checks extend that exact rule, so they compare decoded bytes,
and FR5 was corrected rather than built upon (FR26).

**Lesson 3 quoted a court that no longer existed.** Its LOOK FOR promised
`107/107` and `22/22`, and quoted the `learn` summary as it read before
LRN-2 -- stale since LRN-2, and nothing noticed, because the quotation
check only reads lines that look like a MACHINE speaking. `--check` now
DERIVES the scoreboard from the fixture files the way the court does,
and holds a quotation of its own summary to the summary, which is worded
once (`summary_fmt`).

## PIN-1 -- the court judges its pins, and its first verdict was mine

`PINNING.md` has said "re-pin in the same commit that changes
`fixtures.json`" since the grammar was born, and nothing checked it. The
court now hashes each fixture file before judging a case and fails when
the pin names another file, even with every case passing.

Its first verdict, before a fixture had been touched:

```
FAIL pin -- declarative/machine/fixtures.json hashes to
  4c6aef6163840094, and declarative/machine/PINNING.md pins
  4ed7adee6a389edb
```

The rename of 2026-09-20 (NAME-1) changed fixture A3 -- `stzos project`
became `harb project` inside the cold-room sensor's own comment -- and
never re-pinned. Six days of green courts were about a file the pin did
not name.

## What the real device found

`os7_fleet.sh` gained the retirement arc, and its first run -- expected
to differ from its pin by one added line -- carried **0 entries** off the
device. The tampered record "verified". The foreign record "verified".
Re-pinning that would have written "0 entries verified" into the pin as
correct. Reading the diff instead (SYS-1) found five things:

1. **A byte the rename ate.** `os2_image.sh` line 214 held `sed -e
   's/<CR>$//'` with a LITERAL carriage return. The rename's script read
   every file with Python's `read_text()`, which opens in universal-newline
   mode and turns a lone CR into LF; it wrote back a sed command split
   over two lines, which fails silently inside a pipeline. The second
   boot of every non-SD machine that keeps a JOURNAL has been missing
   from its transcript since 09-20. One CR across all 93 files the rename
   touched (checked in bytes, against both commits); restored as the
   escape `\r` its neighbours use, which no newline translation can eat.
   `qemu_hello`, the one boot that "settled" the rename, keeps no journal
   and never ran that line.
2. **Three digests from before the rename** -- `fleet.expected`,
   `fleet_temoin.expected`, `qemu_identity.expected` pinned
   `declaration=` for machine files whose `RUN ["/stzos", ...]` became
   `RUN ["/harb", ...]`. Each diff read, each cause confirmed at the
   source, each settled by a boot and judged twice. Settling
   `qemu_identity`'s then turned lesson 13 red: it QUOTED the same
   pre-rename digest, and had passed only because the pin was wrong in
   the same way -- both sides wrong together and the court green, PRJ-2's
   shape inside the tour. The quote is kept literal and checked, not
   elided: an elision is a quotation the check skips.
3. **A verification of nothing.** `harb fleet verify` on a record with no
   entries said "0 entries verified ... and no secret took part" and
   exited 0. It now refuses: an attribution of nothing is not one (NS-1).
4. **A verdict the arc discarded.** It ran the device's boot with `>
   /dev/null` and never read its exit code, so a boot that differed from
   its own pin went unremarked -- today it did, on the digest, and the
   arc carried on. NAM-2 exactly; the verdict is received now.
5. **A log that lied on the failure path.** The probe of (4) exited 1
   while `zig-out/wsl/fleet.txt` -- the file every reader is told to
   read -- said the arc matched and exited 0. The log was copied as the
   script's last act, and every early `exit 1` left before it. A `trap`
   writes it on every path now, and it is removed first, so a run killed
   outright leaves no log rather than an old green one.

Then the arc, on a real device:

```
rebuilt: enrol fleet_temoin ed25519 KEY2 -- KEY for this
    machine's MEMBER in a fleet
roll:     retired carte_1 -- a key temoin held before,
    fingerprint FP1, trusted through hash=H
retired: ... 1 entry verified against a key it no longer holds
    (retired as carte_1, fingerprint FP1), ...
stolen: ... entry 2 is not this device's under the key retired
    as carte_1: it comes after the entry ...
stolen: ... 1 entry from there on verifies under the retired
    key all the same: whoever still holds it signed after it
    was retired
```

Nothing is simulated. The rebuilt card is a fresh disk that made its own
key (`KEY2`, distinct by the normaliser's own count). The stolen card is
the first card's saved disk, booted again: it signed entry 2 with the
retired key, and was refused at entry 2. The three original negatives
are word-for-word what they were, which is the proof, on the device, that
rewriting attribution changed nothing it refused before. Pinned at 43
lines, judged twice across fresh keys.

## Probed before it was believed

Nine mutations in fresh builds, each convicting for its own reason, then
the clean tree acquitting with every source byte-identical: the old
enumerating condition (R87 -- accepted), FR5 by text (FR26), a
retirement with no head silently dropped (FR22), fixtures changed without
the pin, the head no longer cutting the chain (the stolen-card test), a
headless chain called kept, lesson 3's old scoreboard, lesson 3's old
`learn` line -- and lesson 3's own BREAK IT, RUN before it was promised,
which now fails twice, on the reason and on the pin. And the arc's new
verdict both ways on the device: a broken device pin exits 1 with a log
that says so; a clean one exits 0.

## Still open

- Retiring the RECORDS a retired card signed: retirement keeps them
  readable, and nothing yet says they are wanted no longer.
- The pins the rename touched that no boot has settled since:
  `qemu_budget`, `qemu_confine`, `qemu_egress`, `names`, `makeen_box`,
  `makeen_qemu` -- textual, no digest, claims until booted. *Settled
  2026-09-27: all six booted and matched unchanged (EGR-3).*
- A lesson for retirement: the tour teaches the fleet (lesson 14) and not
  yet what happens when a card is replaced.

---

# NAME-1 — one word was doing three jobs, and the rename gave all three the same new one

The author ruled the landscape point that STZ-OS-RULING-01 had deferred:
*"you must rename everything harobanda instead of stzos, including the
repo name, and use harb effectively as a command."* Two names, clearly
given. The rename was written as one mapping anyway, and it was wrong in
two directions at once.

## How it surfaced

481 hits across 93 files were sorted first -- which was the right
instinct, and the sort was too shallow. It separated three forms by their
SHAPE: the in-image path `/stzos`, the kernel cmdline namespace
`stzos.slot|expect|watchdog`, and everything else. Ordered rules, most
specific first, so `zig-out/bin/stzos` would not be mangled by the
`/stzos` rule. 611 occurrences changed, "still containing the old name:
none", and then:

```
zig build          ok, zig-out/bin/harb.exe
zig build test     ok
zig build court    107/107 -- 23 accepts, 84 rejects, 0 failures
                    22/22 -- 4 accepts, 18 rejects, 0 failures
harb learn --check  18 lessons: every path they name is present
```

Five judges green, including the two written specifically to catch a
document that has stopped being true. The rename looked finished.

It was not, because the sort had been by shape and the thing that
mattered was by MEANING. `stzos` named three different things:

| what the word named | what it must become | what the rename gave it |
|---|---|---|
| what the reader TYPES | `harb` | `harb` — right |
| the DIRECTORY and the repository | `harobanda` | `harb` — wrong |
| the SYSTEM itself | Harobanda | `harb` — wrong |

**The directory.** 94 references now pointed at `D:\GitHub\harb` and
`/mnt/d/GitHub/harb`, a folder that does not exist and never will: the
author's ruling names the repository `harobanda`, and only the command
`harb`. Eleven of the 94 are inside `src/learn.zig`, in the `run` line of
a lesson -- the exact string the tour tells a reader to type. `learn
--check` walked past every one of them, because a lesson declares the
`paths` it names and its RUN command is not one of them. LRN-1 says a
tutorial is a claim about the system and is judged like one; this is the
part of that claim the judge still does not reach.

**The system.** The worse one, because the court cannot have an opinion
about it. `doc/PROVENANCE.md` carried the dated record of
STZ-OS-RULING-01, and the rename rewrote the record rather than the
world:

```
`harb` — chosen 2026-09-12 by the session on the author's
instruction to choose, under the estate's registers: `stz` is
the distribution, the suffix says which floor.
```

The sentence reasons about a name with an `stz` prefix and a suffix
saying which floor. `harb` has neither. It was true of `stzos`, it was
printed over `harb`, and it was now a sentence that had never been true
of the thing it sat above. That is EGR-2 with the object changed: a
sentence worded for one case and printed for a second is a lie in the
second. `doc/narrations/` had taken the same edit -- "The repository was
named `harb`, provisionally" -- of a day on which it was not.

## What was done

- The directory rule, which the sort had missed entirely: `GitHub/harb`
  -> `GitHub/harobanda`, 94 of them, plus 20 `github.com/mayouni/stzos`
  under `site/` that the first pass had excluded by directory.
- Prose that names the SYSTEM reads Harobanda -- `doc/VISION.md`,
  `doc/GROUND.md`, the fleet grammar, the greeting the machine itself
  prints (`stzr on Harobanda`, re-pinned in `machines/qemu_hello.expected`
  and in the lesson that quotes it). Prose that names the binary or the
  command keeps `harb`, which is most of `src/` and `build.zig`.
- The records RESTORED to `stzos` and amended beside, never rewritten:
  STZ-OS-RULING-01 and the narration's sentence about the day. The new
  ruling is STZ-OS-RULING-02, which states the three names in a table and
  says in as many words what it does not do.
- The `STZ-OS-` prefix on the ruling ids is left alone. It names the
  register the ruling was issued under, not this repository, and the
  estate's memos cite those ids.

## The two the second pass also missed

Two survived even the corrective pass, and they are the interesting
ones. In Zig source the path is written `D:\\GitHub\\harb`, so a rule
matching ONE separator after `GitHub` walked straight past both -- and
both are in the tour's header:

```
  BEFORE YOU START -- Run everything from the repository root,
      ...
  RUN  (from ...)
```

Every lesson prints the second. They were found by running the tour and
reading it, which at that moment was the only judge that reached them:
they are prose, not data, so no amount of checking a lesson's DECLARED
paths could ever have seen them. Sixteen wrong paths in all, three
passes, and the last two were the ones a reader meets first.

## What it cost

Nothing shipped wrong, because every pass ran before its commit. What it
cost is the belief the five green judges bought: every one of them was
green over a repository whose tour told readers to `cd` into a directory
that does not exist.

## Closing it

The seam was closed in the same session, on the author's word. Two
halves, because either alone leaves the hole open.

**Derive.** The repository's directory name is one constant, `repo`, and
every absolute path the tour prints is built from it -- the seventeen
run strings through `RUN_WSL`, both header lines through `WIN`. Nineteen
places that had to agree became one (HDW-1).

**Judge.** Derivation cannot say whether the constant itself is right,
and cannot stop the next literal somebody writes by hand, so `--check`
gained two questions:

- *What is this repository CALLED?* -- read from origin's URL in
  `.git/config`, not from the folder this working copy happens to sit
  in. The first draft asked the folder, which is the question NEXT TO
  the one that decides (MNT-1): a reader's directory is named by their
  clone, so a copy in `~/src/harobanda-fork` is not a broken tour. It
  reported this very working copy, not yet renamed off `stzos`, as a
  lie. The remote is the fact the tour's path is a claim about.
- *Does anything the tour PRINTS name another directory?* -- `list` and
  `all` are rendered into a buffer and every occurrence of `GitHub` in
  the result must be followed by this repository's name. That reaches
  the headers, because it reads what a reader reads rather than what a
  lesson declares. Its first draft required a separator AFTER the name
  and so refused every path that ENDS at the repository root, which is
  what both header lines print: a component ends at a separator or at
  anything that is not a filename character, not at a separator alone.

Probed before it was believed, three mutations in fresh builds:

| mutation | exit | what it said |
|---|---|---|
| `repo` set to the COMMAND's name | 1 | `the tour sends readers to D:\GitHub\harb, and this repository is called harobanda` |
| a header line written out by hand | 1 | `the tour prints GitHub\harb, so that a, which is not this repository` |
| a run string written out by hand | 1 | `the tour prints GitHub/stzos/experiment/os7_fleet., which is not this repository` |

Each fired ONE finding, which is the part worth reading: the first is
invisible to the scan and the other two are invisible to the remote
judge. Derivation keeps the paths consistent with each other; only the
remote can say whether that shared name is right. A clean tree exits 0.

## The doctrine

**A rename is not a search-and-replace, because a name is not a string**
(NAME-1): sort the occurrences by WHAT THE WORD NAMES -- the command, the
place, the thing -- before replacing any of them, and expect a different
new name for each. Shape is not meaning: `/stzos`, `stzos.slot` and
`stzos` sorted cleanly by shape and still put two of the three meanings
in the wrong place.

**A judge that reads the DECLARATION does not judge what is PRINTED**
(NAME-1): a lesson declares the paths it names and `--check` walked all
of them, while the path inside the command it tells a reader to TYPE,
and the two header lines every lesson prints, were judged by nothing.
Render what the reader reads and judge that. The fourth guard in this
log narrower than the thing it guarded (THR-1, SEE-1, LRN-2).

**A rename does not touch a dated record; it amends beside it**
(NAME-1): STZ-OS-RULING-01 chose `stzos` on 2026-09-12, and that
happened. Rewriting it made a document say something that was never
true, and the reasoning it carried -- "`stz` is the distribution, the
suffix says which floor" -- pointed straight at the lie. When a record's
own reasoning stops fitting its subject, the record was edited.

---

# LRN-2 — the tour quoted the machine, and nothing checked the quotations

`harb learn --check` walked every path a lesson names from its first
day, and `zig build court` has run it since. It never looked at the lines
a lesson QUOTES, which is the larger claim of the two: a reader comparing
their screen against a lesson is comparing it against those strings.

## How it surfaced

Writing lesson 17 meant reading the flagship's 129-line transcript
closely, and four of the lines the draft quoted were not what the machine
says. Three had a word capitalised for emphasis inside the quotation
(`ready AND has held`, `ready BUT the boot`, `(VERDICT DIFFERED)`), one
had lost a `(NODEV)`. Emphasis belongs in the prose; a quotation is
either the machine's words or it is a paraphrase wearing quotation's
clothes.

That was enough to suspect a class rather than an incident, so a
throwaway script compared every quoted line in the tour against
`machines/*.expected`. Twenty-three did not match, across four lessons:

- lesson 15, five lines that had lost their `boot: ` prefix -- `box:
  names salle ...` where the machine says `box: boot: names salle ...`
- lesson 14, six lines that had lost their subject -- `verify: 1 entry
  verified ...` where the machine says `verify: fleet atelier -- temoin:
  1 entry verified ...`
- lesson 13, a journal line that had lost its path and its verdict
- lesson 14 again, one line carrying an annotation I had written INSIDE
  the quotation (`(again -- the same key)`)

Every one of them was mine, made while wrapping a long line to fit, and
every one of them would have sent a reader looking for text their machine
never prints.

## The guard

`--check` now flattens every `machines/*.expected` into one haystack and
requires that each LOOK FOR line beginning like a transcript line appears
in it, whitespace normalised so the tour's hand-wrapping cannot hide a
difference. Continuations are joined; fragments under 25 characters and
lines carrying a deliberate `...` elision are exempt.

A BREAK IT's `expect` is exempt BY CONSTRUCTION, and that exemption is
the interesting part of the design: those lines are what the reader sees
AFTER changing the machine, so no pin can hold them. Four such lines
exist today -- lesson 5's `18 lines`, lesson 10's `12 tasks made`, lesson
11's two -- and each was verified by RUNNING the break rather than by
checking it against anything.

Probed: one `boot: ` prefix dropped from a lesson 15 quote, rebuilt, and
`--check` convicts with the offending line printed. Restored, green.

## What this says about the first LRN-1 design

LRN-1 built a check for the part that was easy to check -- do these files
exist -- and the tour then spent its whole life making a different kind
of claim. Eight lessons in, the score is four seats found in the system
(VDCT-1, EGR-2, JRN-2, NAM-2) and two classes of defect found in the tour
itself: break steps that promised the wrong answer, and quotations that
were not quotations.

## The law this pays for

**A quotation is the machine's words or it is not a quotation.** Do not
trim a prefix, a path or a parenthetical to make a line fit, and never
capitalise a word inside one for emphasis -- wrap it, elide it visibly
with `...`, or put the emphasis in the prose. What a tutorial presents as
something the machine SAID must be findable in a pin.

---

# NAM-2 — a guard that checked for an empty answer, not for a refusal

Found by running lesson 15's break and then running the script that reads
the same fleet. Fourth seat out of a BREAK IT step.

## The guard

`os6_names.sh` reads the two hardware addresses out of the FLEET rather
than carrying them as constants of its own, which is HDW-1 and is right.
Then:

```sh
TILL_MAC=$("$S" fleet "$FLEET" hardware caisse)
BOX_MAC=$("$S" fleet "$FLEET" hardware boitier)
if [ -z "$TILL_MAC" ] || [ -z "$BOX_MAC" ]; then
  echo "the fleet did not say which devices these are"; exit 1
fi
```

The guard is looking for an absent answer. A refused fleet does not give
one: it prints its refusal, on **stdout**, and exits 1. So `$TILL_MAC`
held the sentence *"fleet (line 38): boitier promises no address to
52:54:00:99:99:99 ..."*, `-z` was false, and the script sailed past its
own check.

It then built two images, wrote a QEMU command line whose `mac=` was a
whole English sentence, booted both machines, waited for a server that
could not come up, and failed after about two minutes with:

```
the box never said it was serving
```

Which is true, and is four steps downstream of anything a reader could
act on.

## Why this is VDCT-1 one level up

VDCT-1 was a judge that rendered a verdict and did not RETURN it --
`tee` answered for the run. This is the mirror: a verdict WAS returned,
correctly, and the caller read something else. Between them they cover
both halves of the same sentence. A verdict has to be returned AND
received; either side alone is decoration.

The tell is the same in both: a script that reports a symptom long after
the cause, in a place the cause is not visible from.

## The fix, and what was kept

```sh
if ! TILL_MAC=$("$S" fleet "$FLEET" hardware caisse); then
  echo "the fleet is refused, so there are no devices to be:"
  echo "$TILL_MAC"
  exit 1
fi
```

The emptiness check is KEPT underneath, because it was written for a
different case that still exists -- a fleet that judges clean and names
no hardware for a member. Two questions, two guards, rather than one
guard asked to answer both.

Probed both ways:

| fleet | before | after |
|---|---|---|
| a member with an undeclared HARDWARE | ran 2 minutes, `the box never said it was serving` | **2 seconds**, the refusal quoted |
| the committed fleet | clean, 68 lines, exit 0 | clean, 68 lines, exit 0 |

Grepped every other script under `experiment/` for a capture of the same
shape. The only one is a `cat` of a pin file.

## The law this pays for

**A verdict must be RETURNED and RECEIVED; either alone is decoration**
(with VDCT-1). When a caller tests the CONTENT of an answer -- empty,
non-empty, matching some shape -- ask what that variable holds when the
thing that produced it refused. Refusals travel on stdout here, so a
capture that ignores the status captures the refusal as data and carries
it forward as if it were an answer.

---

# JRN-2 — the test named for a POSITION never checked the position

Lesson 13 of the guided tour points at one unit test as its entire
evidence, so writing the lesson meant reading the test. Third seat in
three lessons found this way.

## What it claimed, and what it asserted

`a chain verifies, and an altered entry is named by its position`,
`src/journal.zig`:

```zig
const tampered = try std.mem.replaceOwned(u8, alloc, text,
    "seq=2 prev=", "seq=2 prev=");
const with_lie = try std.mem.replaceOwned(u8, alloc, tampered,
    "verdict=matched hash", "verdict=perfect hash");
const broken = verify(with_lie, pair.public_key);
try std.testing.expect(broken.broken_at != null);
try std.testing.expect(broken.verified < 3);
```

Three things wrong, in rising order of seriousness.

The first line replaces a string **with itself**. A no-op that reads
like an act.

The second replaces over the WHOLE text, and entries one and two both
say `verdict=matched`, so it altered BOTH. The chain therefore broke at
entry **1**, while the comment above it said "ALTER the second entry's
payload" and the test's own name said the position was the point.

And the assertions look at neither. `Check` carries `broken_at` (1-based)
and `reason` (in words). The test asked only whether SOMETHING was wrong
SOMEWHERE. It would have passed had the chain broken at any entry, for
any of the eight reasons `verify` can give.

So the test passed, the name was false, and lesson 13 quoted the name.

## What it asserts now

Tampering line by line, only the line beginning `seq=2 `:

```
broken_at == 2     the position it is named for
verified == 1      entry one still verifies: the break
                   is where the lie is, and not before it
reason contains    "do not hash to the hash it carries"
```

and the foreign-key half, which asserted `broken_at != null`, now
requires `broken_at == 1` and `verified == 0`: offered to a device that
signed none of it, the refusal starts at the first line rather than
somewhere.

## Probed

The tamper was pointed at `seq=1 ` instead and the suite run in a fresh
build: `expected 2, found 1`. The old assertions passed that same
mutation. A test that cannot fail for the right reason is not asserting
the mechanism, it is keeping it company.

## Why this one is worth a tag

The court was probed with a mutated judge before its scoreboard was
written, and that is the doctrine. But the UNIT tests were never held to
it, and this one had drifted from its own name -- quietly, in the file
that carries the strongest claim in the repository. Inalterability is
that a change cannot go unnoticed; the test for it was not noticing
where.

Writing a tutorial that cites a test is a good way to find out whether
the test says what you think. That is now three lessons and three seats:
VDCT-1 from lesson 6, EGR-2 from lesson 11, this from lesson 13.

## The law this pays for

**A test named for a property must assert that property.** `expect(x !=
null)` under a name that promises WHICH is a test of the name, not of the
mechanism. When a test's name, its comment and its assertions disagree,
the assertions are what runs.

---

# EGR-2 — the boot announced a perimeter it was not keeping

Found by a reader doing lesson 11 of the guided tour, one lesson after
VDCT-1 came out of lesson 6. The BREAK IT steps are earning their keep.

## What the step asks

Replace `EGRESS ["10.9.0.0/16"]` with `EGRESS ["0.0.0.0/0"]` -- declare a
reach to everything -- and boot. The witness duly changes:

```
-reach 8.8.8.8 -- no route: this machine knows no way there
+reach 8.8.8.8 -- a route exists: this machine knows a way there
```

And so does PID 1's announcement, into a sentence that is false twice:

```
boot: egress lan -- 0.0.0.0/0 and nowhere else: no default route
```

`0.0.0.0/0` has no `else`. And a route to `0.0.0.0/0` through the
declared gateway is not merely LIKE a default route, it is bit for bit
what the `unrestricted` branch installs when a machine declares no
EGRESS at all. The boot claimed a perimeter while installing none.

## Why it is the NS-1 defect with the sign flipped

NS-1 is about announcing a confinement the mechanism failed to apply. In
this case the mechanism did exactly what the declaration said; it was the
SENTENCE that was wrong, and wrong in the direction that reassures. An
operator reading `and nowhere else: no default route` in a boot log would
conclude the box was confined. It was reachable to the open internet on
the same screen, four lines down.

The two halves of every claim in this repository are the announcement and
the fact, and lessons 7 and 9 both teach the reader to check that they
move together. Here they moved together and the announcement was still a
lie, because it was worded for one case and printed for two.

## The fix, and where it had to go

`egressLine` in `src/expect.zig` -- the ONE place this line is worded,
which is the doctrine holding up. A destination whose prefix is 0 is a
default route, so:

```
boot: egress lan -- 0.0.0.0/0: a DEFAULT route, so this
    machine knows a way anywhere
```

Nothing else moved: no committed machine declares a prefix-0 destination,
and `qemu_egress` re-booted clean against its existing pin afterwards
(exit 0).

## The grammar question this does NOT decide

`EGRESS ["0.0.0.0/0"]` and no EGRESS clause at all now reach the same
addresses by two different routes through the code. Whether the grammar
should REFUSE the explicit form -- say it one way -- is the author's
ruling, not this seat's, and it is left open deliberately. There is an
argument either way: one spelling per meaning, against an operator's
right to be explicit about a decision. What the seat settles is only that
whichever is written, the boot says what it did.

Noted and not changed while there: with `EGRESS [...]` the gateway is
used but the `boot: network` line does not name it, while with no EGRESS
it does (`, gateway 10.0.2.2`). The note means "a default route via this
gateway", which was true of exactly one branch until today. It is now
true of two and printed for one. A seam, named here rather than widened
silently.

## What the transcripts actually distinguish

Running both forms is worth doing for its own sake, because they are NOT
the same record:

| declaration | `boot: egress` line | `boot: network` line | 8.8.8.8 |
|---|---|---|---|
| `EGRESS ["10.9.0.0/16"]` | the perimeter, named | no gateway | no route |
| `EGRESS ["0.0.0.0/0"]` | a DEFAULT route | no gateway | a route exists |
| no EGRESS clause | **absent entirely** | `, gateway 10.0.2.2` | a route exists |

Compare lesson 9, where `SEES [data, logs]` and no SEES clause produced a
byte-identical transcript. Here silence and explicitness reach the same
addresses and leave different evidence: an explicit EGRESS records that
someone decided, and silence records that nobody did.

## The law this pays for

**A sentence worded for one case and printed for two is a lie in the
second.** When a branch grows a value it was not written for -- here a
prefix of 0, which turns a list of destinations into a default route --
re-read the sentence that branch prints before trusting the mechanism
under it.

---

# VDCT-1 — three judges that convicted on screen and reported success

Found by a reader doing lesson 6 of the guided tour, which is the whole
argument for having a BREAK IT step.

## What lesson 6 asks you to do

Change one character in `machines/qemu_hello.expected` -- the pinned
transcript -- boot the machine, and watch the court refuse it. It does,
exactly as promised:

```
JUDGED: FAIL -- the transcript differs from
    machines/qemu_hello.expected:
-boot: console /dev/ttyS9
+boot: console /dev/ttyS0
```

One character, thirty-four lines identical, and the court found the one.
Then the script printed `exit 0` and returned 0 to the shell.

## The bug is one line, and it is the last line

```sh
{
  # the whole run: derive, stage, kernel, image, boot, judge
  echo "exit 0"
} 2>&1 | tee "$LOG"
```

**A pipeline exits with its LAST command's status**, and the last command
is `tee`, which always succeeds. So `os2_image.sh` returned 0 whatever
happened inside it. Not only the verdict: EVERY `exit 1` in that block
-- a kernel build that failed, a missing cross binary, `sfdisk` refusing,
`cpio` never running, the derive refused before staging -- printed its
message and then exited 0. Eighteen of them.

And the `echo "exit 0"` was a hardcoded string that looked like a status
report. It sat directly beneath `JUDGED: FAIL` and said the opposite.

## Then grep for the rest of it

Per the dimension rule, the other judges were checked rather than
assumed:

| script | before | now |
|---|---|---|
| `os2_image.sh` | `} 2>&1 \| tee "$LOG"` -- always 0 | `exit "${PIPESTATUS[0]}"` |
| `os6_names.sh` | `} 2>&1 \| tee "$LOG"` -- always 0 | `exit "${PIPESTATUS[0]}"` |
| `os7_fleet.sh` | `} \| tee -a "$BODY"` then a `cp` -- always 0 | verdict carried past the copy |
| `judge_guarantees.sh` | already `exit 1` on FAIL | unchanged; it is the shape |

`os5_board.sh` and `zigcc_probe2.sh` also pipe to `tee`, and neither
renders a verdict: one captures a serial line, the other reads a
compiler's command line. Checked, not guessed at.

## Probed in both directions, because one direction proves nothing

A judge that always convicts is as useless as one that never does, so
each was run twice -- once with a pin broken at a named line, once with
it restored:

```
os2_image.sh   broken pin -> exit 1     clean pin -> exit 0
os7_fleet.sh   broken pin -> exit 1     clean pin -> exit 0
os6_names.sh   broken pin -> exit 1     clean pin -> exit 0
```

Both callers of `os2_image.sh` were then run end to end. Neither breaks:
`os6_names.sh` invokes it with `HARB_NO_BOOT=1`, which exits 0
explicitly, and `os7_fleet.sh` checks for a file rather than a status.
No script here uses `set -e`, which is why the defect could sit this long
without anything visibly going wrong.

## Why it lasted

Every one of these scripts was read by a person every time it ran. A
human sees `JUDGED: FAIL` and a twenty-line diff and stops. The exit code
is for the reader who is not there -- a `&&` chain, a CI step, a script
calling a script -- and that reader had been told success for as long as
these judges have existed.

The court (`zig build court`) was probed with a mutated judge in fresh
processes before its scoreboard was ever written. The BOOT judges never
were. They rendered their verdicts into a terminal, and a verdict that
only reaches a terminal is a verdict that only convicts people who are
looking.

## The law this pays for

**A verdict that does not reach the EXIT CODE only convicts someone who
is watching.** A judge whose ruling a caller cannot read is a judge in
name. Print the verdict AND return it; a pipeline hides it, so take
`${PIPESTATUS[0]}` and never let `tee` answer for the run.

---

# LRN-1 — the guided tour, and what its first reader taught it within the hour

Asked for by the author: a way to SEE what was built, didactically,
rather than read twenty-four protocol entries in reverse order.

## Where it lives, and why not in a document

Everything here is judged by something that would notice if it drifted:
the grammar by its fixtures, the boot by its own expectation, the
transcript by its pin. A tutorial written as prose has no such judge. It
says "run this and you will see that", and nothing checks that the file
still exists, that the verb is still spelled that way, or that the line
it tells you to look for is still printed.

So the curriculum is a table in `src/learn.zig`, beside the verbs it
teaches, and every lesson declares the paths it names. `harb learn
--check` walks them, and **`zig build court` runs that check** -- so a
lesson pointing at a machine somebody renamed turns the court red in the
commit that renamed it.

Probed, as the doctrine requires: run `harb learn --check` from outside
the repository and it names every missing path and exits 1; from inside,
it exits 0. A judge that cannot convict is not judging.

## The shape of a lesson

Six fields, and the fourth is the whole point.

```
  THE QUESTION        what you do not yet know
  RUN                 one command, copy-pasteable
  LOOK FOR            the exact lines that answer it
  BREAK IT            a change you make so the machine
                      convicts YOU
  THE LAW IT PAID FOR the doctrine sentence, verbatim
  THE FULL STORY      where the account lives
```

**Break it** is why this is a tutorial and not a tour. A guarantee you
have only seen SUCCEED is a claim; one you have watched refuse you is
evidence. That is the same argument IDN-1 made about a signature nobody
tried to break, turned on the reader.

## What the first reader taught it, the same day

The author ran lesson 1. Its BREAK IT step said, in full: *"Add a
service whose RUN is `["sh", "-c", "echo hi"]` and check again. It is
refused BY NAME."* They did it, and it worked -- and then they wrote
back:

> *"When you say 'add a service', tell me how and where… Do not assume I
> know the internals of the system."*

They were right, and the lesson had hidden five separate things in one
imperative sentence: **which** file to edit, **where** in it, **what a
service must contain** to be legal at all, **which directory** to stand
in so a relative path resolves, and **how to put the file back**. They
worked out the first four unaided; nobody told them the fifth, so their
working tree was left dirty by a tutorial.

Two of those were visible in their own screenshot. They ran `harb learn
1` from `zig-out\bin` and `harb check machines\qemu_hello.machine` from
the repository root, because nothing said which, and they had to notice
the difference themselves. And their service declared no `RESTART` and
no `NEEDS` -- so the refusal they got could have been about any of
those, for all the lesson told them.

That last one was worth answering properly rather than asserting. A
probe: the same three lines with `RUN ["/harb", "version"]` in place of
the shell, judged as a copy. **Accepted** -- `4 service(s) … judged, no
refusal`. So `RESTART` and `NEEDS` are optional, everything they had
written was legal, and the shell was the only thing wrong. That belongs
in the lesson, because "it was refused" teaches nothing about what was
refused.

## The redesign: a step is five things, or it is an assumption

`breakit` stopped being a sentence and became a record:

```zig
pub const Break = struct {
    pub const How = enum { append, replace, create };
    // one sentence: what you are about to prove
    proves: []const u8,
    // the file, spelled as you would type it
    file: []const u8 = "",
    // where in it, in plain words
    where: []const u8 = "",
    // add a line, replace one, or make a file
    how: How = .append,
    // the exact text, line by line
    paste: []const []const u8 = &.{},
    // the command
    then: []const u8 = "",
    // the refusal, in the machine's words
    expect: []const []const u8 = &.{},
    // how to put everything back
    undo: []const u8 = "",
    // for a lesson with nothing to edit
    note: []const u8 = "",
};
```

`how` exists because "put this there" does not distinguish adding a line
from replacing one, and that is exactly the sort of thing an author
knows and a reader does not. Two unit tests hold the shape: a step that
names a file must carry `where`, `paste`, `then`, `expect` and an `undo`
containing `git checkout -- `; a step with no file must carry a `note`
saying why there is nothing to edit. **The undo requirement is the
author's dirty working tree, written down so it cannot happen again.**

Every command is now printed as `zig-out\bin\harb.exe …`, not `harb
…`, and every lesson prints `RUN  (from D:\GitHub\harobanda)`. A tour whose
first reader has to guess the working directory has not started
teaching yet. `harb learn --words` was added for the same reason: a
machine, a world, the envelope, the court, a pin, a transcript, PID 1, a
fleet and a seat, in one paragraph each, because every one of them is
estate jargon that reads like an English word.

## Three lessons were WRONG, and only running them found out

A tutorial is a claim about the system. So each BREAK IT step that
promises an answer was run -- on a COPY of its machine, judged, and the
copy deleted. Nine steps in the first pass: **six answered as the lesson
said and three did not**, and all three were errors the author would
have walked straight into.

- **Lesson 16** claimed the refusal was *"one link has one server of
  names"*. It is not. Pointing a second MEMBER at the SAME declaration
  is caught earlier and differently: *"makeen\_names.machine is already
  boitier's declaration: one declaration, one member, or the fleet
  counts one device twice"*. To reach the refusal the lesson is ABOUT,
  the reader needs a second, distinct machine that also serves `salle`
  -- so the step now has them write one (fifteen lines, given in full),
  and then check it alone to watch it pass. Which is a better lesson
  than the one I wrote from memory, and I would not have found it
  without running it.
- **Lesson 15** claimed the reader had to boot two machines to see a
  stranger get nothing. They do not: changing a member's HARDWARE to an
  undeclared address is refused by `harb fleet` in about a second,
  *"boitier promises no address to 52:54:00:99:99:99 … and no pool
  exists to fall back on"*. The declaration IS the register, so a device
  that would go unanswered on the wire is caught in a text file months
  before the wire exists. Cheaper AND a sharper demonstration of the
  law.
- **Lesson 12** paraphrased the key-custody refusal. It now quotes it,
  because the machine's own sentence (*"a key on a filesystem that dies
  with the power is a new device every morning"*) is better than mine.

The rewritten steps were then run again, with the second machine of
lesson 16 written out and judged both ways: **10/10**.

Two more were fixed by the shape rather than by the probe. Lesson 11's
step had been *"delete the EGRESS line, and the comma above it"* --
which is a description, not a paste, and the new unit test would not
accept it; it is now `EGRESS ["0.0.0.0/0"]`, a real line with a real
undo, with the deletion mentioned afterwards as the same result for a
different reason. And lesson 5 no longer promises that a fourth service
makes the boot MISMATCH its expectation: the expectation is DERIVED from
the declaration, so editing the machine moves both sides together. It
matches, the lesson says WHY it matches, and it points at the flagship's
`unmet:` section for the only mismatch there is.

## The second thing the same reader found: the judge nobody mentioned

They ran lesson 5 the next morning and reported the output did not match.
It did -- the line the lesson promised was there, word for word, and the
count it predicted (18, up from 16) was exact. But the lesson had
described ONE judge and the script runs TWO, and the second one FAILS:

```
boot: judge -- the boot matches its expectation
    (/etc/expected, 18 lines)
...
JUDGED: FAIL -- the transcript differs from
    machines/qemu_hello.expected:
```

Both are correct and they say opposite-sounding things, which is the
whole point of having both. The machine's own expectation is DERIVED
from the declaration, so editing the machine moves both sides and it
still matches. The PIN does not move: somebody committed it as a claim
that a RIGHT boot of this machine says exactly this. Edit the machine
and the pin is describing a different machine, and says so.

The reader saw the FAIL last, in a diff twenty lines long, and reasonably
concluded the lesson was wrong.

**Six lessons had this hole, not one** -- 4, 5, 7, 9, 10 and 11 all edit a
pinned machine and then boot it. So the warning is DERIVED rather than
written per lesson: a step whose `file` ends in `.machine` and whose
`then` runs `os2_image.sh` gets an extra rendered section naming the
exact pin that will refuse it, why the refusal is right, and an
instruction not to undo anything yet. A unit test asserts it fires on
exactly those six and nowhere else, and `--check` now walks the derived
`.expected` path too -- a lesson cannot promise a refusal from a pin that
is not there.

Derivation over repetition for the usual reason: six lessons need this
and the seventh will be written by somebody who has forgotten.

## What this seat is actually about

The instrument was already right -- the curriculum in the binary, the
paths judged by the court. What was wrong was the part no judge was
looking at: the prose BETWEEN the judged facts, where an author's
knowledge leaks out as an assumption. `--check` proves a lesson points
at files that exist. It cannot prove a lesson can be FOLLOWED. Only a
reader can, and one did, within an hour.

## The law this pays for

**A tutorial is a claim about the system, so it is judged like one.**
Anything that tells a reader what they will see must fail loudly when
that stops being true -- and a step that cannot name its file, its exact
text, its command, its expected answer and its undo is not a step, it is
an assumption about what the reader already knows.

## Eighteen lessons, six acts

```
I.   THE DECLARATION
     a machine is a text file, judged before anything runs
II.  THE BOOT
     it narrates, it judges ITSELF, and a pin judges that
III. WHAT A WORLD MAY DO
     the envelope, the floor, whose storage, the budgets,
     the reach
IV.  WHO A DEVICE IS
     the key, the signed record, attribution by a stranger
V.   THE NETWORK
     the box as its link's server of names; facts about a SET
VI.  THE FLAGSHIP
     four card boots, a held trial, and the four promises
```

The acts are ordered so that a reader who stops half way has finished a
whole part of the story, and a unit test enforces that an act never
returns after another has begun.

## What runs, and what does not

`harb learn <n> --run` spawns THIS binary with the lesson's own words,
so what executes is exactly what the lesson printed rather than a
paraphrase of it. It works for the four lessons whose command is a verb
of this binary. The boots are WSL scripts and are never spawned from
here: the machine that runs them is not the machine you type on, and
pretending otherwise would be the first lie in a tutorial about not
lying.

## The law this pays for

**A tutorial is a claim about the system, so it is judged like one.**
Anything that tells a reader what they will see must fail loudly when
that stops being true.

---

# THR-1 — whose thread it is: the question dissolved rather than answered

The twelfth act of 2026-09-14, and the last named seam in the envelope.
It was left open for five seats because the question as asked has no
answer, and the seat is what happens when you notice that.

## The question that could not be answered

stzlib's `threads` capability says whether the WORLD may create threads.
NS-1 built the machinery to refuse `clone(CLONE_THREAD)` and then
deliberately did not wire it, because the kernel cannot tell a thread the
Luau script asked for from one stzr made for its own housekeeping.
Refusing them alike would punish the runtime for the world's
declaration. That is a real objection and it does not go away.

## The question that can be

Not *who asked for this thread* but *how many tasks will this machine
hold for this world*. The kernel answers that one exactly, and it is the
same shape as `MEMORY` and `CPU`: a ceiling the declaration sets and the
kernel holds.

```
DEFINE SERVICE swarm AS (
  RUN ["/harb", "swarm", "12"],
  TASKS 6,
  NEEDS [process, filesystem]
) RATIONALE "..."
```

`TASKS n` becomes cgroup v2's `pids.max`, which counts **processes and
threads together**. Together deliberately: a thread and a process are one
`clone` flag apart and the kernel keeps one number, so a floor that
billed them separately would be inventing a distinction the kernel does
not make. The runtime's housekeeping counts against the ceiling, which
is right -- the machine is sizing the WORLD, and stzr's threads are this
world's threads.

## So the capability stays where it was

`threads` is the world's API surface and the runtime's to refuse. It
asks WHO ASKED, which only stzr knows. `TASKS` asks HOW MANY, which only
the kernel knows. They are different questions and each belongs to
whoever can answer it -- which is the whole resolution, and the reason
this floor will never enforce `threads` at the kernel.

## Judged

```
boot: budget -- modest 64 MiB and 50% of a core, swarm 6 tasks,
    greedy 32 MiB; the kernel holds the ceiling, not the world
boot: start swarm -- pid N -- /harb swarm 12
swarm: 5 tasks made, and the kernel refused the next (AGAIN):
    this world is as many as the machine agreed to hold
boot: swarm (pid N) exited 0
```

Five children plus the world itself is six, which is what was declared.
EAGAIN rather than a kill: a ceiling on how many, not a refusal to be --
and the neighbours never felt it, exactly as the memory ceiling of BDG-1
behaves one row below in the same transcript.

**107/107** fixtures, from 104.

## The defect, and it is the third of its kind

The first boot printed `swarm 6 tasks` and the world made all twelve.
`pids.max` had been written on a group nobody was in: `cgroupJoin`
returned early unless the service declared MEMORY or CPU, a guard
written before `TASKS` existed.

That is the third time in two days a guard has been narrower than the
thing it guards -- NS-1's refusal gated on `confined()`, SYS-1's gated
the same way, and now this. The pattern is always the same: a new
dimension is added to a policy, and a condition written for the old
dimensions silently excludes it. **When a policy grows a dimension,
grep for every condition that enumerates the old ones.**

## The law this pays for

**When a question cannot be answered, check whether it is the right
question.** "Whose thread is this" has no answer at the kernel and
never will. "How many tasks may this world have" has an exact one, it
is the question a floor actually needs, and it was available the whole
time.

---

# SEE-1 — per-world sight of the machine's storage: `filesystem` stops being all or nothing

The eleventh act of 2026-09-14, and the first envelope seat that needed
a CLAUSE. The four before it were derived from `NEEDS`, because `NEEDS`
already knew the answer. Which mounts a world keeps is information no
existing clause carries, and inventing a derivation for it would have
been guessing.

## The shape

```
DEFINE SERVICE ledger AS (
  RUN [...],
  NEEDS [process, network, filesystem],
  SEES [data]
) RATIONALE "..."
```

`NEEDS [filesystem]` is the GRANT. `SEES` NARROWS it. That is the whole
semantics and it settles the awkward question about silence: saying
nothing does not widen anything, because the world already declared the
capability, so a world with `filesystem` and no `SEES` keeps every
declared mount -- which is what every machine written before this clause
already did, unchanged.

An empty `SEES` is refused rather than meaning nothing: a world that
wants no storage declares no `filesystem`, and one that wants all of it
says nothing here.

## What it refuses

Five, and the first is the one that keeps the clause honest:

- `SEES` without `filesystem` in `NEEDS` -- a world cannot choose sight
  of storage it never asked to touch;
- a mount this machine does not declare;
- an empty list;
- one mount named twice;
- a machine that declares no `MOUNT` at all, where there is no sight to
  apportion.

**104/104**, from 98.

## The check that had to move

The mount names could not be validated where the clause is read:
`MOUNT`s are parsed AFTER `SERVICE`s, so the service loop would be
asking about something the parser had not read yet. The capability
check, the empty check and the duplicate check happen in the loop; the
"is there such a mount" check is a second pass once the mounts exist.
A refusal must be able to name what the declaration actually contains.

## Judged

`qemu_confine` grew to six worlds and needed a SECOND mount to make the
choice a choice -- with one mount a world either sees the machine's
storage or it does not, and there is nothing to apportion. The two new
worlds are exact mirrors:

```
boot: start ledger ...
confined: /data -- mounted here:
    this world can see the machine's storage
confined: /var/log -- an empty directory and nothing mounted
    on it: ...

boot: start caisse ...
confined: /data -- an empty directory and nothing mounted
    on it: ...
confined: /var/log -- mounted here:
    this world can see the machine's storage
```

Same machine, same binary, same capability granted to both. The only
difference between them is which mount each one named, and neither can
read the other's. That is the shape a business world wants: the till's
own data, and no sight of what it has no business reading.

The `harb plan` output names the narrowing too (`-- sees [data]`), so
an auditor learns which world holds which storage without opening the
machine file.

## The law this pays for

**Derive while the declaration already knows; add a clause when it does
not.** Four seats of envelope came out of `NEEDS` without a word of new
grammar. This one could not, and pretending otherwise -- deriving
"which mounts" from some proxy -- would have been a guess wearing a
derivation's clothes.

---

# KCACHE-1 — one kernel per configuration, not one per architecture

Not a seat: a repair to the court's own instrument, made because the
SYS-1 regression took twenty minutes and the author asked why.

## What it was

`os2_image.sh` kept one kernel tree per architecture and configured it
afresh for whichever machine was building. But a machine carries the
kernel ITS OWN declaration needs, so every machine asks that tree for a
different kernel -- 502 options for `qemu_hello`, 634 for `qemu_egress`
-- and each one reconfigured and rebuilt what the machine before it had
just finished building.

The measurement that names it, from the SYS-1 regression in the order it
ran:

| machine | kernel build |
|---|---|
| qemu_hello | 1m16 |
| qemu_budget | 1m31 |
| qemu_identity | 2m07 |
| **fleet_temoin** | **0m06** |
| qemu_egress | 2m23 |
| makeen_qemu | 3m04 |
| makeen_box | 3m13 |

`fleet_temoin` wants exactly the 559 options `qemu_identity` wants and
ran straight after it, so the tree was already configured that way and
`make` had nothing to do. One row got a cache hit by accident of
ordering; the others paid full price for a kernel that had existed an
hour earlier.

## What it is now

One SOURCE tree per architecture, extracted once. One BUILD directory
per CONFIGURATION, keyed by the first twelve hex of the fragment's
sha256, built out-of-tree with `make O=`. A configuration is built once
and reused; two machines that want the same kernel share it; and the
boot log says which it got:

```
kernel cache: MISS x86_64-f4e24d5fe4b5
    -- first build of this configuration
real    1m49.423s
kernel cache: HIT x86_64-f4e24d5fe4b5
    -- this configuration is already built
real    0m6.611s
```

Then the test that matters, because the old layout's whole failing was
that machines evicted each other: run `qemu_egress` in between, and come
back.

```
qemu_egress   MISS 2m25.615s
qemu_hello    HIT  0m4.756s
```

And the whole regression, twice, every run judged against its pin:

| machine | pass 1 | pass 2 |
|---|---|---|
| qemu_hello | MISS 1m50 | HIT 0m05 |
| qemu_budget | MISS 1m45 | HIT 0m05 |
| qemu_identity | MISS 1m59 | HIT 0m05 |
| fleet_temoin | HIT 0m05 | HIT 0m05 |
| qemu_egress | MISS 2m13 | HIT 0m07 |
| makeen_qemu | MISS 2m57 | HIT 0m06 |
| qemu_confine | MISS 2m10 | HIT 0m08 |
| makeen_box | MISS 3m11 | HIT 0m04 |
| **total** | **16m10** | **0m45** |

Sixteen minutes of kernel builds becomes forty-five seconds, and all
sixteen runs matched. `fleet_temoin` is a HIT on the second row of the
FIRST pass, which is the key fix showing its work: it shares
`qemu_identity`'s configuration and no longer builds it again.

The out-of-tree build produces the same kernel; only where it is kept
has moved.

## The key is what the fragment ASKS FOR, not the file

The first key was the sha256 of `kernel.fragment`, and it was wrong in a
way the cache itself exposed within minutes: `qemu_identity` and
`fleet_temoin` want byte-identical options and got two separate builds,
because the derived fragment opens with a comment naming the machine it
came from. Hashing the file hashed the comment.

The key is now the CONFIG lines alone -- keeping `# CONFIG_X is not
set`, which looks like a comment and is a setting -- and the two collide
as they should.

## Why the sources moved too

`make O=` refuses a source tree that was ever built IN -- it wants
`mrproper` first. The existing `$K/<arch>` trees are dirty from every
in-tree build since OS-2, so the sources now live at `$K/src/<arch>`
and get extracted clean. **The old `$K/<arch>` trees are superseded and
can be deleted**; about 7 GB, and nothing reads them any more.

## What it does not change

The rule it exists to serve: a machine still carries the kernel its own
declaration needs, and nothing was merged into a common superset to make
the cache cheaper. Two machines share a build exactly when they ask for
the same thing, which is a fact about their declarations rather than a
convenience arranged here.

---

# SYS-1 — the syscall surface: the machine is not a world's to change

The tenth act of 2026-09-14, and the first of the envelope seats that is
NOT derived from `NEEDS`.

## Why this one is different

The three before it all asked the same question: *what did this world
declare?* This one asks a different one: *what is a world, on this
floor?*

The machine's own law says there is no shell, no package manager and no
service manager, and that the declared machine IS the system. A world
computes and talks to what it declared. It does not remount the
filesystem, set the clock, load a kernel module, rename the host, build
itself a new envelope, read another process's memory, or reboot the box.

No clause grants those, because **no declaration should ask**. So they
are refused to every world on every machine, with EPERM, whatever its
`NEEDS` say -- and `qemu_confine`'s `open`, which declares `process`,
`network` and `filesystem` and is held to nothing on its own account, is
refused them exactly like the others.

## The list, and one absence

Twenty-five calls in four groups: the filesystem tree (`mount`,
`umount2`, `pivot_root`), the kernel (`init_module`, `finit_module`,
`delete_module`, `kexec_load`, `kexec_file_load`), the machine's own
life and identity (`reboot`, `settimeofday`, `clock_settime`,
`adjtimex`, `clock_adjtime`, `sethostname`, `setdomainname`), and the
envelope and the plumbing (`unshare`, `setns`, `ptrace`, `swapon`,
`swapoff`, `bpf`, `syslog`, `acct`, `mknod`, `mknodat`).

A call absent on an architecture emits no instruction at all, so the
filter never tests a number that means something else there.

The absence worth naming: this is **not** a default-deny allowlist. That
would be the strong form, and it would mean enumerating everything stzr
needs on two architectures and being wrong somewhere nobody notices
until a world dies in a restaurant. What is claimed is exactly what is
built: a named, closed list of things a world may not do, not a proof
that everything else is safe.

## The order that makes it possible

The filter is installed LAST, after the unshares that build the
envelope. That is why it can refuse `unshare` and `mount` -- PID 1 has
already used them, and the world never will.

## Judged

Two new tests beside the code: a world that declared everything still
carries the floor's refusals, and every call in the list appears on
every filter whatever the world declared. And the boot says it once,
per machine rather than per world, because it is a fact about the floor
and not about any declaration:

```
boot: floor -- the machine is not a world's to change:
    none may mount or unmount, set the clock, load a module,
    rename the host, make or enter a namespace,
    trace another process, or reboot the box
confined: the floor -- refused by the kernel (EPERM):
    this world cannot change the machine it runs on
```

The witness TRIES it rather than reporting it, and the call it tries is
`unshare` -- chosen because if the filter is not there, all that happens
is the world gets a mount namespace of its own and exits. **A witness
must not damage the machine in the case where the guard it is testing
has failed**, which rules out trying `reboot` to prove reboot is
refused.

## Two defects, and neither was in the filter

Both were found by REFUSING TO PIN A TRANSCRIPT WITHOUT READING ITS
DIFF, which is the only reason this entry is not a lie.

**The kernel could not build the filter on a machine with no network.**
`CONFIG_SECCOMP_FILTER depends on HAVE_ARCH_SECCOMP_FILTER && SECCOMP &&
NET` -- the kernel builds its filter engine on the BPF core, which lives
under `NET`. So `qemu_hello`, which declares no network at all, got
`EINVAL` from `seccomp()` and PID 1 refused to start a world it could
not confine. Three of its worlds did not run. That refusal is the NS-1
law doing exactly its job, and it is the second time a namespace or a
filter has turned out to depend on `CONFIG_NET` -- the first was
`NET_NS`, three seats ago. A machine with no wire now gets `CONFIG_NET`
anyway when it needs the floor's refusals: a machine carries the kernel
its own declaration needs, and since this seat every declaration needs
them.

**And the worse one: the refusal was guarded too narrowly.** PID 1 only
refused to start a world when `held.confined()` -- when the world's own
`NEEDS` had asked for something to be taken away. But since this seat
EVERY world has an envelope, so on `qemu_identity`, whose worlds declare
everything, the filter failed silently, the boot printed

```
boot: floor -- the machine is not a world's to change: ...
```

on its console, and nothing at all was behind it. The machine announced
a guarantee it had not kept -- the NS-1 defect, in its third incarnation
and its best hiding place yet, because the transcript looked perfect and
the boot judged itself a match. The guard is now simply "the kernel
could not build this world's envelope", with no condition on whose
account it was being built.

## The law this pays for

**Some things are refused by what a world IS, not by what it declared.**
When no declaration should ever ask for something, do not add a clause
that could grant it -- refuse it to everyone and say so once.

**And: a pin is not a record of what happened, it is a claim that what
happened was right.** Copying a transcript over its expectation without
reading the diff turns a broken world into the new definition of
correct. Every re-pin in this seat was diffed against a checker that
allows exactly two changes -- the floor line appearing and the judged
count moving by one -- and four pins made before that checker existed
were reverted.

## What it cost, measured

The eight-machine regression took about twenty minutes, and the kernel
is all of it. One row of the timings says why:

| machine | kernel build |
|---|---|
| qemu_hello | 1m16 |
| qemu_budget | 1m31 |
| qemu_identity | 2m07 |
| **fleet_temoin** | **0m06** |
| qemu_egress | 2m23 |
| makeen_qemu | 3m04 |
| makeen_box | 3m13 |

`fleet_temoin` wants a kernel with exactly the 559 options
`qemu_identity` wants, and it ran straight after it, so the shared
tree was already configured that way and `make` had nothing to do.
Every other machine paid a full reconfigure because the machine before
it had left the tree configured for something else. That is the whole
cost, and KCACHE-1 turns every row into the `fleet_temoin` row.

---

# PID-1 — the process table: a world that never asked for processes is alone in one of its own

The ninth act of 2026-09-14, and the last of the three that close "what
a world can see". Still no clause.

## What `process` means, stated once

stzlib's capability is *spawn and manage*, and managing is inspecting
and signalling as much as starting. So a world that never asked for
`process` now gets none of it: it cannot create one (NS-1), and it
cannot SEE or signal one either. The pids of the other worlds do not
exist in its table, so they cannot be named, let alone killed.

## The trap in the middle of it

`unshare(CLONE_NEWPID)` does **not** move the caller. It makes the
caller's future CHILDREN the inhabitants of a new table. A world that
unshared and then exec'd would still be standing in the machine's own
table, with a guarantee printed about it and nothing behind the
guarantee -- the NS-1 defect again, wearing a different hat.

So the child forks once more. The grandchild is pid 1 of the new
namespace and becomes the world; the process left behind is a STAND-IN
that exists only to carry the world's fate back unchanged:

- an exit code exits,
- a signal is re-raised on itself,

so `boot: kds (pid N) exited 0` and the killed-by-the-kernel line the
BUDGET seat depends on both stay true through a process nobody declared.

And `/proc` is remounted inside, or the world would read the machine's
table through the mount it inherited and see every other world. That is
why the mount namespace is now asked for by EITHER reason -- the storage
(MNT-1) or the table -- and asked for once.

## What made it safe to do at all

PID 1 never signals a world. It spawns and it reaps, and nothing else,
so the signal shielding a namespace's init acquires changes nothing
here. The kernel's own OOM kill, which the BUDGET seat relies on, is
SIGKILL from an ancestor namespace and reaches a namespace init
regardless. Both checked before a line was written.

## Judged

`still` declares `network` and `filesystem` and not `process`, and gives
four independent answers, each from one word above it:

```
confined: eth0 -- present:
    this world shares the machine's network
confined: processes -- this world is pid 1 and no other process
    exists here: a table of its own
confined: /data -- mounted here:
    this world can see the machine's storage
confined: fork -- refused by the kernel (EPERM):
    this world cannot start another process
```

`exited 0` came back through the stand-in unchanged.

And `makeen_box` again: both its worlds declare `NEEDS [network,
filesystem]`, so both are now daemons that are pid 1 of their own
tables, behind a stand-in, with a remounted `/proc`. **All 125 lines
across four card boots match** -- they came up, signalled ready, held
their health windows, and the trial committed. The only line that
changed in the whole file is the wording of the confinement itself.

## The law this pays for

**A namespace the caller does not enter is a namespace nobody is in.**
`unshare` is not `enter`: check which side of the call the guarantee
lands on, and if it lands on the children, make one.

---

# MNT-1 — the mount namespace: a world that never asked for the filesystem does not get the machine's storage

The eighth act of 2026-09-14, and the other half of the envelope NS-1
opened. Still no clause.

## What is taken, and what is deliberately not

A world whose `NEEDS` omits `filesystem` runs in its own mount namespace
with every DECLARED `MOUNT` detached. It keeps the image it was built
from, because its binary is a file and a world with no files is not a
world. It loses the machine's STORAGE -- which is where everything worth
keeping from a world lives: the device key, the signed boot record, the
business data.

That line is the whole design. The profile's implicit `proc`, `sysfs`
and `devtmpfs` stay: they are the machine's plumbing, not its storage,
and a world that cannot see `/proc` is a world that cannot run.

## The safety step that is not optional

Before any detach, the tree is made `MS_REC | MS_PRIVATE`. Without it
the umounts PROPAGATE BACK to the machine, and a single confined world
takes `/data` away from every other world and from PID 1 itself. A mount
namespace that shares propagation is not an isolation; it is a way to
break the box from inside a world.

## Judged

`machines/qemu_confine.machine` grew to four worlds and three questions,
and every cell is explained by the line above it:

```
                      eth0        /data       fork
  sealed   no network  not there   mounted     permitted
  still    no process  there       mounted     refused, EPERM
  open     everything  there       mounted     permitted
  blind    only process not there  NOT MOUNTED permitted
```

`blind` asked for nothing but the right to run, so it gets nothing but
that. It is the world a sovereignty brief wants for anything handling
data it must not be able to send anywhere -- DIKO's ESC6 read from the
other side: not "may not leave the perimeter" but "has nowhere to send
it from and nothing to send".

## The defect, and it was the witness rather than the mechanism

The first run reported `/data -- there` for `blind` and the promise
looked broken. It was not: `/data` is a DIRECTORY in the image, put
there so PID 1 has somewhere to mount onto, and it stays after the
detach. `access()` answers about the directory and says nothing about
what is mounted on it.

The honest question is the one `mountpoint(1)` asks: a path is a
separate filesystem exactly when its device id differs from its
parent's. The witness now compares them with `fstatat` -- `stat` does
not exist as a syscall on aarch64 at all -- and says which of the two
things it found:

```
confined: /data -- mounted here:
    this world can see the machine's storage
confined: /data -- an empty directory and nothing mounted on it:
    this world has a mount namespace of its own and the
    machine's storage is not in it
```

A witness that asks a question next to the one that matters will report
a kept promise as broken, which costs exactly as much trust as the
reverse.

## One tolerated failure, on purpose

`umount2` returning EINVAL is not treated as trouble. It means nothing
was mounted at that path -- and then the world cannot see the machine's
storage there either, so the promise is kept vacuously. Cascading a
failed boot-time mount into a refusal to start every confined world
would punish the worlds for the machine's own fault.

## The law this pays for

**Ask the question that decides, not the one next to it.** The witness
is part of the evidence, and a witness answering an adjacent question is
a witness giving the wrong verdict with full confidence.

---

# NS-1 — namespaces and seccomp: the kernel keeps the promise NEEDS has been making since the first day

The seventh act of 2026-09-14, and the only one so far that added no
clause at all.

## The promise that was kept by good manners

`NEEDS` has said what each world requires since the first machine file.
The runtime refused what was not granted; the KERNEL handed it over
anyway. A world that never declared `network` could open a socket. A
world that never declared `process` could fork. The declaration was
true about intent and false about the machine.

Here the kernel keeps it instead, derived and never declared:

| the world's NEEDS omits | what the kernel does |
|---|---|
| `network` | it runs in its own EMPTY network namespace -- the interface is not refused, it is not there |
| `process` | `fork`, `vfork` and `clone` without `CLONE_THREAD` return EPERM |

## Why the vocabulary already fit

stzlib's nine capabilities separate `process` from `threads`, and the
kernel separates them at exactly the same seam: one `clone` makes either,
and one bit of its first argument says which. The filter tests that bit,
which is what makes the refusal precise rather than a blanket ban on
`clone` that would break every runtime that threads. A vocabulary
written for a virtual twin turned out to name the distinction the kernel
actually makes.

## The one deliberately NOT enforced

`threads`. A capability says what the WORLD may do, and a thread the
RUNTIME creates for its own housekeeping is not the world asking: stzr
is a process this machine starts, not a program the declaration wrote.
Refusing it a thread because a Luau script never asked for threading
would punish the runtime for the world's declaration. The machinery to
refuse it is built and judged; the seat that decides whose thread it is
is not.

## Judged

`machines/qemu_confine.machine` -- three worlds, one witness, and the
only difference between them is what their own NEEDS say:

```
boot: confine -- sealed has no network of its own,
    still has no way to start another process
confined: eth0 -- no such interface from here: this world has
    a network namespace of its own and there is nothing in it
confined: fork -- permitted: this world started another process,
    and this line is the child speaking
confined: eth0 -- present:
    this world shares the machine's network
confined: fork -- refused by the kernel (EPERM):
    this world cannot start another process
```

`harb confined` asks a sharper question than `harb reach`: not whether
the machine knows a WAY to an address, but whether the interface EXISTS
from where the world stands. "No such interface" is a different answer
from "no route" in the way that matters -- there is nothing here to be
refused.

And the flagship earned something. `makeen_box` declares `NEEDS
[network, filesystem]` for both its worlds -- no `process` -- so both
now run under a filter that refuses process creation. **All 125 lines
across four card boots match**, which means stzr genuinely does not
fork: the declaration was TRUE, and the kernel now holds it.

## Three defects, and the second is the serious one

**The witness said everything twice.** A fork copies the buffer as well
as the process, so the child's flush re-emitted what the parent had not
yet written. Flush before forking.

**The confinement was ANNOUNCED and did nothing.** The first run printed
`sealed has no network of its own` while sealed had the whole network:
`unshare` failed, `apply` recorded the failure in a field nobody read,
and the boot went on. That is the exact defect this repository exists to
refuse -- a claim the machine did not keep, in the transcript that is
its evidence. PID 1 now does not start a world whose envelope it could
not build: it says so and exits 125, the boot differs from its
expectation, and a trial holds.

**And the reason it failed was a claim that was empty anyway.**
`unshare` answered EINVAL because `CONFIG_NET_NS` depends on
`CONFIG_NET`, which a machine with no declared network never enables.
The right fix was not to force the option on: a machine with no wire has
no network to keep a world off, so there is nothing to refuse and
nothing to say. `qemu_hello` went back to the transcript it has had
since the first day, which is the correct outcome and looks like no
work at all.

## The law this pays for

**A promise the machine announces and cannot keep is worse than one it
never made.** When the mechanism behind a declared guarantee fails,
refuse the act and say so; never print the guarantee and continue.

---

# HDW-1 — the hardware clause: the last fact about a deployment that lived in a shell script

The sixth act of 2026-09-14, and the smallest. It deletes a constant.

## What was wrong

`machines/makeen_names.machine` promises `192.168.10.40` to a peer
identified by a hardware address. `machines/caisse_makeen.machine` is
the till that will claim it and says nothing about its own hardware.
The only thing connecting the two was this, in `experiment/os6_names.sh`:

```
# the `caisse` peer, declared in the box
TILL_MAC=52:54:00:12:34:61
```

A comment. In a shell script. In a repository whose entire argument is
that a fact about a deployment belongs in a declaration a court can
read — and the fleet court, one seat old, could not check the one
correspondence that decides whether the deployment works at all.

## Where it belongs, and why not the machine

On the MEMBER, beside `KEY`. A machine file is a DESIGN and one design
images many devices; a hardware address belongs to one of them. That is
exactly the distinction the key already draws: both are facts a
DEPLOYMENT learns, never facts a design states.

## What the join buys

Five refusals that hold the promise and the machine against each other,
none of which any single file can fail:

- a device that asks on a served link and is in the server's register
  under no peer at all -- it will never get an address, because there is
  no pool to fall back on (FR16);
- a device the server promises one address and which takes another
  itself (FR17);
- the server appearing in its own register, which would be a machine
  asking itself for an address it already has (FR18);
- two members claiming one device (FR15), and hardware that is a word
  rather than an address (FR14).

**22/22**, from 16/16. And the roll now says the join out loud:

```
caisse -- caisse_makeen (caisse_makeen.machine, asks)
    -- 52:54:00:12:34:61, promised 192.168.10.40 as caisse
```

A `PEER` no member claims is deliberately NOT refused. The kitchen
printer is a declared peer of the box and will never be a Harobanda
machine; the fleet checks the members it has and says nothing about the
rest of the wire.

## The proof is a pin that did not move

`experiment/os6_names.sh` now reads both addresses from the declaration
through `harb fleet <file> hardware <member>`. The 66-line names
transcript **matched unchanged** on the first run afterwards: the
declaration supplies exactly what the constants did, and now a court can
check it. A seat whose whole result is that nothing visible changed is
the right shape for this one.

## The law this pays for

**A fact about a deployment lives in a declaration, or it is not a fact
anyone can check.** When one turns up in a script, move it and delete
the constant -- do not add a second place that has to agree.

---

# FLT-1 — the fleet court: machines judged together, and one device's record verified by another

The fifth act of 2026-09-14, and the one the IDENTITY and JOURNAL seats
were waiting for.

## The gap it closes

A device makes its own Ed25519 key on first boot and never sends the
private half anywhere (IDN-1). It signs its own boot record with it
(JRN-1). Put those together and you get a record only its author can
verify — which is attribution nobody else can test, and the IDENTITY
seat already ruled on that shape of thing: a signature nobody tried to
break is a claim, not evidence.

A fleet closes it with arithmetic rather than trust. It records each
member's PUBLIC key, which proves nothing about anyone else and may be
held by anyone, so **any holder of the fleet file can verify any
member's record** and no secret takes part in the act.

## Why a second file and not a bigger one

Every check until now could be made by reading one machine. These
cannot be made that way at all:

- two boxes that each declare themselves the server of `makeen` are each
  a faultless machine, and together they are a network where two
  machines hand out the same addresses and neither is wrong;
- two machines that each take `192.168.10.7` are each correct alone;
- a till that asks for an address on a link nobody serves never gets
  one, and nothing in its own file is wrong.

Facts about a SET belong in a file about a set. It is the SAME language
— same tokenizer, same clause machinery, same refusal channel — and a
file is judged by which kinds it may contain. A machine file declaring a
`FLEET` is refused by name; a fleet file declaring a `MACHINE` is
refused by name.

`src/fleet.zig`'s third unit test says it best: it declares both
machines successfully, one after the other, and then refuses the fleet
they make.

## Enrolment is not prophecy

A `KEY` cannot be declared before the device that makes it exists. So a
member without one is NOT refused — it is reported, in these words:
*KEEPS A RECORD AND IS NOT ENROLLED: nobody can verify what it signs*.
The court refuses what is wrong; the roll says what is incomplete.

Enrolment stays manual on purpose. A fleet that enrolled whatever key
answered would attribute records to whatever device happened to be
plugged in. The enrolled key implies the fingerprint the device prints
on its own console, so the roll prints it and an operator compares the
two by eye.

## Judged

**16/16** fleet fixtures (`declarative/fleet/fixtures.json`), every
reject a case where each machine is faultless alone. **Three unit
tests** on attribution. And the whole arc on a real device
(`experiment/os7_fleet.sh`, **26 lines** pinned), where the negatives
decide it:

```
verify:     temoin: 1 entry verified against the enrolled key
    (fingerprint FP1), and no secret took part
tampered:   temoin: entry 1 is not this device's:
    the entry's own bytes do not hash to the hash it carries
foreign:    temoin: entry 1 is not this device's:
    this device's key did not sign this entry
unenrolled: temoin has no KEY in this fleet:
    nobody can speak for its records
```

The device makes a NEW key on every run of that script and the pin still
holds — each distinct key becomes `KEY1`, `KEY2`, … in order of
appearance, so the persistence claim survives and only the randomness is
erased.

## Two defects, one of them old

`harb attest --export` failed on the device with `cannot read
--export: FileNotFound`: the verb took the first argument as its file
path and a flag is not a path. Fixed by picking the first argument that
is not a flag.

And the normaliser matched `fingerprint [0-9a-f]+` against a transcript
containing `fingerprint after its next boot`, so it read the `af` of
`after` as a fingerprint and wrote a token into the middle of an English
word. Values are now MARKED by `sed` at their exact lengths before `awk`
maps the distinct ones. **The same fragility had been in
`experiment/os2_image.sh` since IDN-1**, unexposed only because no line
there ever put a word after `fingerprint`.

## The law this pays for

**A claim only its author can check is not evidence.** The floor holds
the secret; the fleet holds what anyone may check; and the two never
meet in one place.

---

# NAM-1 — the box as the network's own server of names, and the first time two machines met on a wire

The fourth act of 2026-09-14, and the first one whose proof needed a
second machine.

## The ground, which is not ours

RestoLean's B7 states it from the merchant's side. Many boxes do not
keep their register of leases across a reboot: the kitchen printer
comes back on a different number and somebody re-types it into the
till. Makeen lives with this. It has nothing to do with us, and that is
exactly why it is worth solving — "Makeen would solve a problem he has
today that has nothing to do with us" is the strongest form a floor's
value can take.

The answer B7 names is a box that hands out the addresses itself,
reserves them all, and gives names: `imprimante.makeen`.

## The design is a removal

`DOMAIN` on a NETWORK makes the machine that link's server. `PEER`
declares who is on it. **There is no pool and no range.** The machine
serves exactly the peers declared and nobody else.

So the failure is not handled — it is made impossible to have. The
register of who has which address cannot be lost at a reboot because
there IS no register: there is the declaration, in git, judged by the
court before the image was built. And the lease is offered INFINITE
(option 51, `0xffffffff`), which says the true thing: this address is
this device's because it was declared, not because a timer has not run
out yet.

Two more removals, both of them refusals to lie:

- **No router option.** This machine does not forward, and a box that
  named itself the way out without being one would be lying to every
  device on the link. Forwarding would be an act, and an act is
  declared; there is no clause, so there is no forwarding.
- **No referral.** A name the box does not serve is `NXDOMAIN` — a true
  statement about this network — never forwarded upstream. The box
  speaks for its own link and is silent about the rest of the world.

## Judged by the thing that consumes it

Eight refusals and one accept widened the court to **98/98**. Four unit
tests judge the codec beside the code. But the claim "this box serves
`imprimante.makeen`" is not proved by the box saying so, and PRJ-2
already paid for that law: a generated artifact is judged by what
CONSUMES it.

So `experiment/os6_names.sh` boots **two machines at the same time**,
joined by a QEMU socket netdev, which is a real L2 segment between
exactly two machines. It is the first time anything in this repository
needed more than one. The box is started, and the script waits not for
a guessed number of seconds but for the line the box itself prints:
the wire is ready exactly when the server says it is.

`machines/caisse_makeen.machine` declares no address, no resolver and
no printer. It is the till:

```
till: boot: network salle -- eth0 up 192.168.10.40/24 (dhcp),
    dns [192.168.10.1], names on makeen (/etc/resolv.conf)
till: ask imprimante.makeen -- 192.168.10.50 (from 192.168.10.1)
till: ask imprimante -- 192.168.10.50 (from 192.168.10.1)
till: ask makeen -- 192.168.10.1 (from 192.168.10.1)
till: ask fantome.makeen -- no such name on this network
    (from 192.168.10.1)
```

And the seat's own negative, in a third round: the SAME image, with a
hardware address nobody declared.

```
stranger: boot: network salle -- eth0 dhcp:
    no lease after 3 tries (no server answered on this network)
```

That line was not written for this seat. It is what the DHCP client has
said since NET-1 when nobody answers, and it is the truth about a
network that was never told about this device.

## The defect the first paired run exposed

The box **halted**. With no services declared, PID 1 reached `every
service has ended -- init has nothing left to keep alive` moments after
its verdict, and was gone before the till finished booting. The till
was correct to report that nobody answered.

The fix is not a flag. A machine that is its link's server of names has
not finished when its last one-shot has: every device on that network
asks it for an address at every boot and for a name whenever somebody
types one. A box that stopped the moment nobody was asking would be a
box that works until it is needed. PID 1 now says so and waits:

```
box: boot: every service has ended -- and this machine is
    still makeen: a server stops when the machine stops,
    not when the asking does
```

## Also paid for here

`zig build cross` caught a `Network` literal in `net.zig` missing its
new field — the third time that rule has earned itself, and the second
time on this exact file. The host build was green.

The Bash tool mangled `\n` inside a heredoc into a real newline twice,
producing a Zig string literal with a line break in it. The standing
workaround is the one that works: write the Python to the scratchpad
with the file tool and run it.

## The law this pays for

**A machine that serves a link is not finished when its services are.**
Serving is a state of the machine, not a task that completes.

---

# JRN-1 — the machine's own record: chained, signed, and never extended when it does not verify

The third act of 2026-09-14, and the one where the scope mattered more
than the mechanism.

## Whose record this is

RingServ described the target precisely, from a real constraint: French
anti-fraud law requires cash-register software to guarantee
inalterability, security, retention and archiving of sales records, and
its own shape log is "a sync convenience -- derived from tables,
deliberately trimmable, holding row images", which is "the opposite on
every axis" of what that law wants.

So the temptation was to build a business journal here. **This is not
one.** `JOURNAL` records what the MACHINE was and what it judged of
itself: one line per boot, carrying the digest of the declaration that
ran and the verdict PID 1 reached. What a record of business IS belongs
to the world that keeps it, and a floor that invented that would be
inventing its customer's domain.

The two compose exactly as MicroRing's identity design says: a device
signature attributes a record BEFORE it enters any ledger, and a chain
orders records WITHIN one. A world's journal of signed records sits
above this one; neither replaces the other.

## The record

Plain text, one entry per line, because a record a person cannot read is
a record nobody audits:

```
seq=1 prev=- machine=qemu_identity declaration=a48c59fbf8070f67
    verdict=matched hash=<64 hex> sig=<128 hex>
```

`hash` is sha256 of everything before ` hash=`, and `sig` is Ed25519
over those same bytes -- the exact bytes on the line, not the object
they came from, which is MicroRing's rule and removes the class of bug
where two spellings of one record verify differently.

**No timestamp, deliberately.** The board has no clock of its own and
nothing on the boot path sets one, so a time in this file would be the
epoch wearing the authority of a date. The SEQUENCE is the order, and a
trusted clock is a named seam whose field can be appended to the payload
the day one exists.

## The rule that makes it worth keeping

**Verified before it is extended, and never extended when it does not
verify.** An entry appended after a broken one launders the break. A
machine that cannot keep its record has not booted as declared, so the
trial that would have committed is HELD -- the journal is not advisory.

And the claim is stated exactly: inalterability is not that a record
cannot be changed (any file can be changed) but that a change cannot go
UNNOTICED.

## Judged

The chain's logic is judged beside the code (`src/journal.zig`): three
entries verify; one word changed in entry two -- the verdict, which is
exactly the field someone would want to change -- is caught with its
position and its reason; a signature from another device is refused.

`qemu_identity` is now booted TWICE on the same disk, because a record
of one boot proves nothing about a chain (46 lines):

```
boot: start record -- pid N -- /harb journal
journal /data/boot.journal -- no record yet: this is the first
    boot, and its entry is written after the verdict
boot: judge -- the boot matches its expectation
    (/etc/expected, 13 lines)
boot: journal -- /data/boot.journal: the chain begins,
    entry 1 signed by this device (verdict matched)
...
again: journal /data/boot.journal -- 1 entry, every one chained
    to the one before it and signed by this device
again: journal:   seq=1 prev=- machine=qemu_identity
    declaration=a48c59fbf8070f67 verdict=matched
again: boot: journal -- /data/boot.journal: 1 entry verified,
    entry 2 appended and signed (verdict matched)
```

`makeen_box` (121 lines) carries it across four card boots, and the
entry the UNMET trial wrote is the one worth reading:

```
unmet: boot: journal -- /data/boot.journal: the chain begins,
    entry 1 signed by this device (verdict differed)
```

The box wrote down that its boot was not the declared one. That is the
line an auditor wants and the line a vendor's box would never keep.

## The defect the repeated boots exposed

The final normaliser stripped everything before `boot: harb init` on
EVERY line that matched, not only the first -- so the banner of a later
section (`steady:`, `again:`) lost its prefix, and several boots' first
lines read identically in one file. It went unnoticed while no machine
booted twice. Fixed to the first line only, which is the line the
firmware noise actually precedes.

## The law this pays for

**A record is the floor's or a world's, never both.** The machine says
what the machine did; what a business record is stays the business's.

---

# IDN-1 — a device is somebody: a key made once, kept where the power cannot take it, and a court that boots the same card twice

The second act of 2026-09-14. A box's name is a label; its KEY is who it
is. Until today every Makeen box in the world would have been the same
box to anyone reading a record it produced.

## The seat, and the design it borrows

`IDENTITY "<path>"` on a hosted MACHINE: where this device's own key
lives. PID 1 makes an Ed25519 pair there the first time the machine ever
boots, and loads it every time after. Fixture-first (A19, R64, R65, R66;
85/85 after, from 81/81).

The design is **MicroRing's**, read before a line was written, and two
of its findings are law here:

- **Ed25519 because of what it does not need.** Signing is deterministic
  (RFC 8032), so no nonce is drawn at signing time, and a board with no
  entropy source worth the name cannot leak its key by drawing a bad one.
- **The algorithm and the custody are SAID, never implied**, because the
  two are coupled: a key held in silicon may be a P-256 key, since some
  signing peripherals do not speak Ed25519. A record that assumed one
  algorithm would be the uniform pretence that design refuses. So the
  transcript says `ed25519, custody a file at /data/device.key`.

And the refusal that matters most is the one about WHERE:

```
R65: IDENTITY /tmp/device.key is where the key lives, and no
     declared MOUNT keeps it: a key on a filesystem that dies
     with the power is a new device every morning
```

R66 refuses the whole clause on the edge profile and says whose it is:
an edge device's key is MicroRing's, and its custody is the hardware's.

## The witness

`harb attest`, as `harb id` is the USER seat's and `harb reach` is
EGRESS's. It signs with the device's key, verifies the signature against
the public half, and then **flips one bit in the message and shows the
same signature refused**. That second half is what makes the first half
evidence rather than a claim: a signature nobody tried to break proves
nothing.

## The claim is persistence, so the court boots the same card TWICE

A key that is made and used in one boot proves nothing about identity.
`experiment/os2_image.sh` now boots the card again after the trial has
committed, and that boot is where both of the first boot's decisions are
read back:

```
boot: identity -- ed25519, custody a file at /data/device.key
    -- created on this device, fingerprint KEY1
...
steady: boot: slot B -- committed, steady
steady: boot: identity -- ed25519, custody a file at
    /data/device.key -- already on this device, fingerprint KEY1
```

The held and unmet trials run on PRISTINE copies of the card and each
makes its own key (`KEY2`, `KEY3`) -- because a fresh card is a fresh
device, which is exactly what an identity should mean.
`makeen_box.expected` is now **117 lines** across four card boots.

## Normalising a value without hiding the claim

A fingerprint is the one thing a declaration cannot know: it is made on
the device from the device's own randomness, and a machine that could
derive it from its file would have no identity at all. So the derived
expectation ends in the wildcard, and the judge does NOT replace the
fingerprint with a constant -- that would erase the very claim. Each
DISTINCT fingerprint becomes `KEY1`, `KEY2`, … in order of first
appearance.

Measured: two consecutive builds, real fingerprints
`8038fb3d6c45b2de` and `b6a136f719a92fa3`, one pinned transcript. And a
key that CHANGED between two boots of one card would read as `KEY2` and
convict.

## What is NOT claimed

The private half never leaves because **no code in this repository sends
it**, and no world can read it because the file is the machine's own and
a world that declares a USER is not the machine. That is not the same as
hardware custody: a key in a secure element cannot be read by software
at all, and that is a different seat -- the edge profile's question
first, where MicroRing already named the coupling it costs.

## Judged

- `qemu_identity`: **18 lines**, new and pinned.
- `makeen_box`: **117 lines** (from 84), four card boots.
- `qemu_hello` 33, `qemu_egress` 19, `qemu_budget` 35, `makeen_qemu` 26:
  unchanged. A machine that declares no identity says nothing about one.
- 12/12 unit tests, 85/85 fixtures, the guarantees and the projection
  unchanged.

## The law this pays for

**A name a device cannot keep is not a name.** An identity that does not
survive the power is a new device every morning, and the declaration is
refused rather than believed.

---

# EGR-1 — a perimeter the declaration writes: how far a granted network reaches

The first act of 2026-09-14, and the one with a customer requirement in
a signed proposal behind it. DIKO's specification, requirement ESC6:
child-protection and gender-based-violence data must never leave the
organisation's perimeter. Until today the machine language could say
that a box speaks -- `CAPABILITY network` -- and not one word about
whom to.

## The seat

`EGRESS` on a NETWORK: a list of destinations, or the word `none`.

```
DEFINE NETWORK lan AS (
  INTERFACE "eth0",
  ADDRESS "10.0.2.15/24",
  GATEWAY "10.0.2.2",
  EGRESS ["10.9.0.0/16"]
) RATIONALE "The programme's own range, reached through the
  gateway, and nowhere else"
```

Fixture-first, the court red for four named reasons before the parser
was touched (A18, R60, R61, R62, R63; 81/81 after, from 76/76). The
sharpest refusal is R60: **a gateway is a way out, and `EGRESS none`
says there is none** -- declare one or the other.

## What it does, exactly

It writes the ROUTING TABLE from the declaration. With a declared reach,
one route per destination is installed and **no default route at all**;
with `none`, no route is added and the box knows no way off its own
link; saying nothing is what every machine did before this seat, where a
declared GATEWAY becomes a default route.

## What it is NOT, said as plainly

**This is the routing table, not a packet filter.** The guarantee is
*the machine knows no way there*, not *the machine is prevented from
finding one*. A world with the privilege to add a route could add one --
there is no shell on the boot path to do it with, and a world that runs
as a declared USER has no such privilege, but the distinction is real
and the claim stops where it stops. A netfilter seat over netlink would
be the stronger statement; it is named here and not built.

Stated that way, it is still the answer a clause in a contract cannot
give: a box that cannot route to the open internet does not have to be
TRUSTED to refrain.

## Judged by the kernel's own answer

`machines/qemu_egress.machine`, the sixth pinned transcript, 19 lines:

```
boot: network lan -- eth0 up 10.0.2.15/24
boot: egress lan -- 10.9.0.0/16 and nowhere else:
    no default route
boot: start allowed -- pid N -- /harb reach 10.9.0.1
reach 10.9.0.1 -- a route exists: this machine knows a way there
boot: start denied -- pid N -- /harb reach 8.8.8.8
reach 8.8.8.8 -- no route: this machine knows no way there
```

Note the network line: no `gateway` clause, because with a declared
reach no default route was installed -- the line says what happened,
and the egress line says the reach.

`harb reach <a.b.c.d>` is the witness, as `harb id` was the USER
seat's: it asks the KERNEL and says what it answered. A UDP `connect()`
is the whole question -- it performs the route lookup and sends nothing
-- so a machine with no way to an address learns that **without a single
packet leaving it**, which is the point when the address is one the
perimeter forbids.

## What the cross build caught, again

The host build was green and `zig build cross` was not: two errors in
code only Linux compiles -- a Network literal in the by-hand `harb net`
verb missing the new field, and a double pointer where the new line is
printed. The rule in `CLAUDE.md` earned itself again: a Windows build
proves nothing about the init.

## Judged

- `qemu_egress`: **19 lines**, new and pinned.
- `makeen_box` **84** and `makeen_qemu` **26**: unchanged. They declare
  no reach, so they say nothing about one -- a machine written before
  this seat has the transcript it always had.
- 12/12 unit tests, 81/81 fixtures.

## The law this pays for

**A capability says what kind of effect a machine may have; only a
declaration of reach says how far.** Granting the network and leaving
the destination to whatever the box happens to find is how data leaves a
perimeter nobody wrote down.

---

# OS-5-PREP — the board's first boot, written and rehearsed before the board exists

Last of the five acts of 2026-09-13. OS-5 itself is NOT done: no card
has been flashed and no board has booted. What is done is everything
that can be done without one, so that the first real boot is a command
rather than an improvisation — and so that whatever it says is judged by
instruments that were written while nobody knew what it would say.

## `experiment/os5_board.sh`, four acts

**`card`** — what to flash and what it is. The digests of the machine
file, the card, the kernel and the initramfs; the boot the BOARD expects
of itself, printed in full; the two lines the emulator could not keep;
then the wiring (GPIO 14 and 15 with a ground, 3.3 V, 115200 — the
mini-UART the machine declares as `CONSOLE /dev/ttyS1`).

And one check worth the whole act: **the card's own boot line carries no
instrument of the court.** Every instrument is the emulator's — the
watchdog turned off, the lens chosen, the boot halted at the verdict —
and a card that carried one would be a box that behaves like a court,
which is the one thing a box on a counter must never do. The script
reads `cmdline.A.txt` and `cmdline.B.txt` and refuses to go on if it
finds `harb.watchdog=off`, `harb.expect=`, `--halt-on-verdict` or
`--hold`. Today they are clean:

```
  cmdline.A.txt: console=ttyS1,115200 quiet loglevel=3
      harb.slot=A rdinit=/harb -- init /etc/machine
  clean: the card boots the box, not the court
```

**It never writes to a device.** Flashing is the one act here that can
destroy a computer if a letter is wrong, so the script prints the
command and the author runs it. The Windows tools are named first
because they refuse a system disk.

**`listen <dev> [seconds]`** — the console, captured to a file at
115200 8N1, with the `usbipd attach` line WSL needs before a USB serial
adapter exists inside it at all.

**`judge <file>`** — three judges on one captured boot:

1. **the board's own verdict**, which PID 1 printed on that console: the
   machine judging its own boot against the `/etc/expected` it carries
   (JDG-1);
2. **the court's verdict**, the same judge run from the host over the
   captured text — `harb judge <machine> <transcript>`, new here. Two
   independent witnesses to one boot, which is the reason to keep both;
3. **the four standing promises** (GRT-1), which on a board should for
   the first time be kept all four by ONE text.

Then it names what a board is expected to say that the emulator could
not, and what only a board can show: the watchdog's real countdown, and
the tryboot flag that still needs a vendored patch to `bcm2835_wdt.c`.

**`rehearse`** — the same three judges against the emulator's pinned
transcript, with no hardware at all. That is how this script was proven
today:

```
--- 1. the BOARD's own verdict
       (what PID 1 said about its own boot)
    the boot matches its expectation
        (/etc/expected.emulator, 17 lines)
--- 2. the COURT's verdict (the same judge, run from the host)
    judge makeen_box -- the boot this machine EXPECTS
        (emulator lens, 17 lines)
      every expected line was said
```

## `harb judge` — the host's own reading

The machine judges its LEDGER as it boots; this judges the TEXT a serial
cable carried away. A captured transcript is not a ledger: it carries
the kernel's lines, the worlds' output and the console-only lines PID 1
says about the card. So the comparison is one-sided on purpose — every
expected line must have been said, and everything else the machine said
is printed rather than judged, because a real boot legitimately says
more than its expectation.

It reuses the derivation and the comparison the machine itself uses
(`src/expect.zig`), so the two witnesses cannot drift: one wording, two
readers.

## What waits on the author

`STZ-OS-HARDWARE-01`: a Raspberry Pi 4 Model B, a micro-SD card, and a
3.3 V USB-serial adapter. Nothing else. The card image is built, its
digests are printed, the wiring is written down, and the judges are
rehearsed.

---

# GRT-1 — the guarantee sheet becomes a verdict: four promises, judged by name against the machine's own evidence

Fourth of the five acts of 2026-09-13. `GROUND.md` had written the item
itself: *RestoLean's four guarantees should be four named expectations
judged by the court, so that "always reachable, stable name, durable
log, survives the cut" is a verdict, not a brochure.*

## Whose promises these are

A restaurant's, first. RestoLean's Makeen thread called MakeenOS "a
posture, never a marriage": a sheet of guarantees that imposes itself
over whatever host is underneath, written by Amor in four words each --
*toujours joignable, nom stable, journal local durable, traverse la
coupure*.

They are not one customer's, which is why `harb guarantees` carries
them as the HOSTED PROFILE's four standing promises. A box behind a
counter, an NGO's hub in Diffa, a bank's server and a school's machine
make the same four or say they make none. `qemu_hello` says it makes
none, and that is a verdict too: **0 of 4 promised**.

## What the verb does

`harb guarantees <file.machine> <text>` reads the DECLARATION for what
is promised and a TEXT for what is kept, and says one of three things
per promise: not promised, KEPT (with the line that keeps it, quoted),
NOT KEPT (with what was looked for and not found). Nothing restates the
declaration as its own evidence -- a promise is kept only if a line of
the text says so.

Two promises are also ORDERING claims, and the judge checks the order:
the wire and the partition must be up BEFORE the first world starts,
because a world that starts on a floor which is not ready has already
been told a lie.

## Judged twice, because two texts are needed today

`experiment/judge_guarantees.sh` runs it against both, and the pinned
verdict (`machines/makeen_box.guarantees.expected`, 39 lines) holds both
reports:

- **the board's expectation** (`zig-out/image/makeen_box/expected`,
  derived through the board's lens): **3 kept** -- the wire up at its
  declared address before any world, the address declared and not
  leased, the partition mounted before any world spoke. The fourth is
  NOT KEPT for a reason the judge states precisely: *this text carries
  no slot decision -- an expectation stops where the verdict begins*.
- **the court's transcript** (`machines/makeen_box.expected`, what the
  emulator really printed): **1 kept** -- the durable log. The other
  three name the emulator's own lacks: `the wire never came up -- boot:
  network lan -- eth0: no such interface (NODEV)`, `no line carries
  192.168.10.1/24`, and the watchdog line that says a trial cannot roll
  back by hardware there.

Neither text can keep all four, and the pair says exactly why. That is
the honest state of the box until OS-5 puts a card in a board: on that
day ONE transcript keeps all four, and this verb is what will say so.

## The mechanism, asserted before its scoreboard

Two mutations, each in a fresh run:

- the mount line removed from the expectation → *a durable log: NOT
  KEPT -- no line says 'mount ext4 at /data -- done'*;
- the wire's line moved AFTER the first start → *always reachable: NOT
  KEPT -- the wire came up AFTER a world had started*.

## The defect the first run found, in the judge itself

The first version searched the whole text for a substring and reported
**a stable name: KEPT** — citing the line
`unmet: boot: judge -- expected, not said: network lan -- eth0 up
192.168.10.1/24`. A promise judged kept by the very line saying it was
missing.

A transcript carries more than one boot: the court runs the same card
again held and again through another lens, prefixing those (`hold: `,
`unmet: `), and PID 1 QUOTES lines it expected and did not say. Both
answer a substring search; neither is evidence about this boot. So
evidence is now what PID 1 said about THIS boot: a line that begins
`boot: ` and is not the judge quoting.

## The law this pays for

**Evidence is what the machine said about this boot, never what it
quoted about another.** A judge that searches a whole text will find the
words it wants inside the sentence that denies them.

---

# BDG-1 — a budget the KERNEL holds: the wall between one world and the next, and the gate that made the transcript a fact

Third of the five acts of 2026-09-13. The dividend document promised a
wall between an inference world and the kitchen display; this is that
wall, built while the only thing on the other side of it is a stand-in
that allocates.

## The seat

`MEMORY <mebibytes>` and `CPU <percent of one core>` on a service.
Fixture-first as always (A17, R56, R57, R58, R59; the court red for
four named reasons before the parser was touched; 76/76 after, from
71/71).

```
DEFINE SERVICE greedy AS (
  RUN ["/stzr", "/app/greedy.luau"],
  RESTART on_failure,
  READY "/run/greedy.ready",
  MEMORY 32,
  AFTER [modest],
  NEEDS [process, filesystem]
) RATIONALE "..."
```

## The mechanism, which cost this repository nothing

cgroup v2 is a filesystem: a group is a directory, and a ceiling is a
line of text written into it. So a budget needs no daemon, no agent and
no library. PID 1 stays in the root group (exempt from the
no-internal-process rule), delegates `+memory +cpu` to its children,
makes one directory per budgeted world, writes `memory.max` and
`cpu.max`, and moves each world into its own group between the fork and
the exec -- so a world is never outside its ceiling for an instant.

A machine that declares no budget mounts no cgroup filesystem and asks
for no controller: the plan shows the mount only when a world asks for
one, and the kernel fragment gains its five options only then.

**The two ceilings do different things, and the difference is the
point.** Memory KILLS -- SIGKILL, inside the world's own group, with the
neighbour untouched. CPU THROTTLES -- the world waits for its next
slice and nothing dies, so a held cpu ceiling appears in no transcript
at all.

## Judged by a world the kernel kills

`machines/qemu_budget.machine`, the fourth pinned transcript: `modest`
holds 8 MiB of its 64 and ends; `greedy` asks for far more than its 32
and is killed by signal 9, five times, each restart the declared policy
and each kill the kernel's:

```
boot: budget -- modest 64 MiB and 50% of a core, greedy 32 MiB;
    the kernel holds the ceiling, not the world
boot: start greedy -- pid N -- /stzr /app/greedy.luau
greedy: this world was granted 32 MiB,
    and is about to ask for far more
boot: greedy (pid N) killed by signal 9
boot: restart greedy (on_failure, 1/5) -- pid N
...
boot: greedy -- restart on_failure, but gave up after 5 restarts
boot: every service has ended
    -- init has nothing left to keep alive
```

35 lines. The world's own file carries a bound of 512 MiB that the
kernel should never let it reach: if the ceiling did NOT hold, the
transcript would say so in one line instead of hanging. The machine
never reaches a verdict on its own boot, which is the truth about a
boot where a world never served.

## The gate: what this act found in the old code

Adding the budget changed the timing of the smallest machine, and its
pinned transcript FLIPPED two lines:

```
-boot: start whoami -- pid N -- /harb id -- as world (1000:1000)
 id: uid=1000 gid=1000
+boot: start whoami -- pid N -- /harb id -- as world (1000:1000)
```

PID 1 could only print a start line AFTER the fork, because the line
carries the pid -- and `harb id` is a static binary that prints one
line and exits, so it beat its own start line to the console. The race
had always been there; every earlier transcript had simply won it.

**The fix is a gate, not a wider normalisation.** Between the fork and
the exec the child now blocks on a pipe, so PID 1 can put it in its
cgroup and SAY that it started before the world says anything. One
spawn path serves both a world with a declared USER and one without,
the credential drop happens at the same moment it always did, and the
order of every transcript became a fact rather than a margin. The
proof: `qemu_hello` matched its ORIGINAL pin again, unchanged, 33
lines.

## Judged

- `qemu_budget`: **35 lines**, new and pinned.
- `qemu_hello` **33**, `makeen_qemu` **26**, `makeen_box` **84**: all
  matched their existing pins after the gate, none re-pinned.
- 12/12 unit tests, 76/76 fixtures, the projection and its consumer
  unchanged, the WSL rehearsal still catching its stale world.

## The law this pays for

**A transcript whose order depends on which process reaches the console
first is a margin, not a fixture.** Where PID 1 must speak before a
world does, it holds the world until it has spoken.

---

# HLT-1 — the watchdog is fed on HEALTH: a world can be alive and wedged, and until today nothing noticed

Second of the five acts of 2026-09-13, and the second half of the
guarantee RestoLean's sheet calls *traverse la coupure* — survives the
cut. SRV-1 gave the box worlds that serve. This one asks what happens
when a world is still there and no longer serving.

## What was wrong

The hardware watchdog was fed every turn of PID 1's loop, unconditionally.
So it protected the box against exactly one thing: PID 1 itself dying,
or the kernel hanging. A kitchen display whose process is alive and whose
service has stopped — the ordinary failure of a real box — fed the
watchdog just as happily as a healthy one, and an A/B trial committed on
a world that had served for an instant.

## The seat

`HEALTH <seconds>` on a service that declares READY: the window within
which the daemon must REFRESH that path. Fixture-first, as always — the
court went red for three named reasons before a line of the parser was
written (A16, R53, R54, R55; 71/71 after, from 67/67).

```
DEFINE SERVICE kds AS (
  RUN ["/stzr", "/app/kds.luau"],
  RESTART always,
  READY "/run/kds.ready",
  HEALTH 5,
  NEEDS [network, filesystem]
) RATIONALE "..."
```

One path, two roles, and R45 still holds: one path signals for one
service. The world creates it to say *I am serving*, and touches it to
say *I am serving still*.

## What it changes, in three rules

1. **The feed.** PID 1 feeds the hardware only while every world with a
   window is fresh. The first that goes stale is named — `kds -- stale:
   /run/kds.ready has not been refreshed for 6s (window 5s)` — the feed
   stops, and the board's reset into the committed slot is the answer.
2. **The commit.** A trial commits only once every such world has been
   ready THROUGH one full window. "Serving" measured at the instant of
   the signal is not worth an update; "serving one window later" is. The
   commit line says so in the transcript.
3. **The latch.** Staleness does not clear. A world that recovers does
   not resume the feed, because a feed that resumed would hide exactly
   the fault the watchdog exists for. AFTER is untouched: readiness is
   still the signal, so nothing waits a window to start.

A world that deletes its own signal is stale too — the check reads the
path's mtime, and a missing path is not a fresh one.

## The negative, demonstrated

`machines/wsl_rehearsal.machine`'s `signals` service is
`flock /tmp/harb-signals.ready /bin/sleep 30`: it CREATES its path at
start and never touches it again. That is precisely the world HEALTH
exists to catch, and it was already in the rehearsal for another reason.
With `HEALTH 2` declared it is caught in seconds, with no kernel and no
emulator:

```
boot: signals -- stale: /tmp/harb-signals.ready has not been
    refreshed for 2s (window 2s)
boot: this machine declares no SLOTS and arms no watchdog;
    on a board a stale world is what resets it
```

The rehearsal's `--turns` went from 8 to 12 for one reason, stated in
the script: the run has to OUTLIVE a window, or it proves nothing.

## The positive, pinned

The box's worlds refresh every second against a five-second window. The
card's three boots are unchanged in kind and now carry the rule:

```
boot: health -- kds every 5s, poste every 5s;
    a world that stops refreshing stops the watchdog
boot: slot B -- committed: every service is ready and has held
    its health window and the boot matches its expectation
```

- `makeen_box`: **84 lines** (from 81), three card boots.
- `makeen_qemu`: **26 lines** (from 25).
- `qemu_hello`: **33 lines, untouched** — one-shots declare no window.
- The two lenses still differ on exactly the emulator's two lacks.
- 12/12 unit tests (the window's own logic is judged beside the code:
  ready at the signal, proven one window later, the latch, and a world
  with no window owing nothing), 71/71 fixtures.

## The law this pays for

**Alive is not serving, and a watchdog fed by the fact that a process
exists guards nothing that matters.** The declaration now carries the
difference, and the hardware answers to it.

---

# SRV-1 — the box's worlds SERVE: a daemon never exits, and an init that waits for an exit learns nothing more

First of the five acts the author ordered on 2026-09-13, and the one
everything else stands on: until today the Makeen box's two worlds were
stand-ins that printed two lines and exited, so every box transcript was
a lie of shape. A kitchen display serves a service; it does not end.

## The declaration first

`machines/makeen_box.machine` and `machines/makeen_qemu.machine` now say
what the worlds are:

```
DEFINE SERVICE kds AS (
  RUN ["/stzr", "/app/kds.luau"],
  RESTART always,
  READY "/run/kds.ready",
  NEEDS [network, filesystem]
) RATIONALE "The kitchen display world: a daemon that serves
  the kitchen and says so by creating its READY path; PID 1
  keeps it alive for the life of the box"
```

The grammar needed nothing new: RESTART and READY were seated at RDY-1.
Fixture A2 is `makeen_box.machine` verbatim, so it was RE-TAKEN from the
file mechanically rather than hand-copied, and `fixtures.json` re-pinned
in this commit (67/67, unchanged: the widening was a machine's, not the
language's).

## The runtime owed them one primitive

A daemon has to YIELD. Luau's sandbox ships no timer, so stzr gained a
fourth granted capability beside `readfile` and `writefile`:
`sleep(ms)` (`stz/src/main.zig`, judged by `stz/experiment/run_sleep.luau`,
6/6). The alternative was a busy loop, and a busy loop lies twice: it
reports "serving" while it spins a core, and under TCG emulation it
spends the boot's own time. A negative argument is refused rather than
rounded to zero — silence about a wrong argument is how a daemon becomes
a one-shot nobody noticed. The suite was probed with the wait removed
(`sleep(0)` where `sleep(120)` stood): red for its named reason, exit 1.

## The defect a daemon found, which no one-shot could

The first boot with a serving world stopped dead after the kitchen
display signalled. `poste` never started; the court's timeout was the
only thing that noticed.

**PID 1 was blocking on `wait4` for a child that never exits.** Two
bugs, one cause — the loop assumed every change arrives as an EXIT:

1. `startReady` was called only when a signal was still OUTSTANDING
   (`if (awaiting)`), never when one had just APPEARED. The moment the
   display's path showed up, nothing was awaiting any more, so the world
   that came AFTER it was never started.
2. With no service awaiting and no slots, the loop chose a BLOCKING
   `wait4`. A daemon never exits, so that call never returns.

`pollReady` now reports both facts the loop needs — a signal APPEARED
(start what waited on it) and a signal is OUTSTANDING (keep polling) —
and the loop polls while any of four things is true: the watchdog needs
feeding, a signal is outstanding, a service has not started yet (only a
signal can start it), or the court's instrument is still owed a verdict.

## The instrument: a served boot still has to close

A real init keeps a served machine alive for years. A transcript that
never closes is not a fixture, so `harb init --halt-on-verdict` halts
the moment every service is ready AND the boot is judged. It is DERIVED
from the declaration — any service that is not a one-shot — onto the
EMULATOR's boot line only; the card's `cmdline.txt` never carries it,
because a board must keep the box alive. No verdict is no halt: a daemon
that never signals leaves the court's timeout to convict it, which is
"no expectation is no commit" seen from the other side.

## The ordering trap, found in the same run

The worlds wrote their READY path and THEN printed "serving". PID 1
polls every 250 ms, so its `ready` line could land between the two — a
transcript whose order depends on a poll is not a fixture. The signal is
now the LAST act of a world, after everything it has to say. And PID 1
flushes its own lines when a signal is seen: a served machine never
reaches the reaper's flush, because no child exits, so without it PID 1's
lines arrived in a batch at the end.

## Judged

- `makeen_qemu`: **25 lines** (from 23). Both worlds serve, signal, and
  are seen; `judge -- matches (/etc/expected, 15 lines)`; the boot ends
  on the instrument.
- `makeen_box`: **81 lines** (from 75), three card boots unchanged in
  kind — the trial commits and the card boots B, the held trial does not
  and the card boots A, the trial judged through the BOARD's lens names
  the emulator's two lacks, holds itself, and the card still boots A.
- `qemu_hello`: **33 lines, untouched** — every service is a one-shot,
  so no instrument is derived onto its line. It stays the control case.
- The WSL rehearsal, the projection and its consumer, the stzu
  meta-court: unchanged. 11/11 unit tests, 67/67 fixtures.

## The law this pays for

**A daemon never exits, so an init that waits for an exit learns nothing
more.** Every loop that watches a machine must ask what happens when
nothing ends — and the answer must be in the transcript, not in a
timeout. The one-shot machine hid this for a day and a half; the first
world that served found it in one boot.

---

# JDG-1 — the machine judges its own boot: the expectation rides in the image, a trial commits only on a match

The author said: close the loop. The loop was this: every boot was
judged from OUTSIDE — QEMU's serial transcript, normalised and diffed
by a script against `machines/<name>.expected` — while the machine
itself committed an A/B trial on "every service is ready" and nothing
else. The Makeen box's emulated trial committed with its network
refused NODEV, and the court was green, because the court judged the
transcript and the machine judged nothing.

## What closes it

`harb image` now DERIVES the init lines a faithful boot prints — from
the plan, through a LENS — and the initramfs carries them as
`/etc/expected`. PID 1 records every judged line it says (a ledger:
written first, then echoed to the console, so the two cannot disagree)
and, the moment every service is ready, judges the ledger against the
expectation in its own words:

```
boot: judge -- the boot matches its expectation
    (/etc/expected.emulator, 16 lines)
boot: slot B -- committed: every service is ready and the boot
    matches its expectation; config.txt now boots B,
    A is the fallback
```

The rule for a trial changed from "ready" to "ready AND matches". A
boot that differs names the lines and holds itself:

```
boot: judge -- the boot differs from its expectation
    (/etc/expected): 2 line(s) expected and not said,
    2 said and not expected
boot: judge -- expected, not said:
    network lan -- eth0 up 192.168.10.1/24
boot: judge -- expected, not said:
    watchdog armed (/dev/watchdog)
boot: judge -- said, not expected:
    network lan -- eth0: no such interface (NODEV)
boot: judge -- said, not expected:
    watchdog -- off by the boot line (the emulator resets on
    arming); a trial cannot roll back by hardware here
boot: slot B -- held: every service is ready but the boot is
    not the one expected; not committed, the watchdog is no
    longer fed -- the next boot is A
```

No expectation is no verdict, and nothing to judge by is nothing to
commit on: text before act, applied to the act itself.

## The lens

The emulator lacks what the board has — no GENET, and a watchdog it
resets on — so one expectation cannot be true of both. The image
derives two: `/etc/expected` (the board's) and `/etc/expected.emulator`
(the emulator's), from one plan and a `Lens` with one field per lack.
The emulator's boot line says `harb.expect=emulator`, beside the
`harb.watchdog=off` it already said; the card's `cmdline.txt` never
does. **The diff of the two texts IS the list of the emulator's lacks**,
printed at build time:

```
--- the emulator's lacks (expected vs expected.emulator):
  the board:  boot: network lan -- eth0 up 192.168.10.1/24
  the board:  boot: watchdog armed (/dev/watchdog)
  the emulator:  boot: network lan -- eth0: no such interface
      (NODEV)
  the emulator:  boot: watchdog -- off by the boot line (the
      emulator resets on arming); a trial cannot roll back by
      hardware here
```

The sentence this repository has repeated since OS-4 — "the board is
expected to differ exactly where the emulator lacks the hardware and
nowhere else" — is now a derived text, and the board's first boot
(OS-5) will be judged against `/etc/expected` by the board itself.

## Two rules, no diff, no timer

The pids the kernel hands out are normalised to `N`; `pid 1` stays
literal, because that init IS PID 1 is a claim the judge must be able
to convict (the script's judge keeps it for the same reason). A line
the declaration cannot fully know — a dhcp lease — ends in `*` and
matches by prefix: `network lan -- eth0 up *` met `10.0.2.15/24,
gateway 10.0.2.2 (dhcp), dns [10.0.2.3]` on `virt`. Nothing else is
loose. The lines are compared as a SET: AFTER already enforces the
order that matters, and two daemons signalling ready in either order
are the same boot. Count is judged: a line said twice is a restart, and
a restart before readiness is not the boot that was declared.

Every judged line is worded ONCE, in `src/expect.zig`: init prints
with those format strings and `derive()` writes the same. A line worded
twice would drift, and a drift is exactly the false alarm a
self-judging machine must never raise. The wording is still pinned from
outside by the three transcripts, so a drift would be convicted twice.

## What is judged, and what is not

The ledger holds what init said about the MACHINE: the banner, the
console, the slots, every mount's result, every capability, every
network's result, the watchdog, every start, every exit and signal
before readiness. It does not hold what the CARD says (a trial, or
steady — the declaration cannot know which boot this is), the
instrument's lines (`--hold`), or the verdict itself. What comes after
readiness — the exits of daemons, the halt — is the court's to judge,
not the machine's.

## Judged, three machines and three card boots

- `qemu_hello`: `judge -- the boot matches its expectation
  (/etc/expected, 14 lines)`; pinned at 33 (from 32).
- `makeen_qemu`: matches, 15 lines, the lease through the wildcard;
  pinned at 23 (from 22).
- `makeen_box`, three boots on `raspi4b`: the trial through the
  emulator's lens matches (16 lines) and commits, the card boots B; the
  same trial held by the instrument matches and is held, the card still
  boots A; and the NEGATIVE, new: the same trial judged through the
  BOARD's lens (`boot_unmet.cmd`, the emulator's line without its lens)
  differs on exactly the two lacks, holds itself, the card still boots
  A. Pinned at 75 (from 49).
- the WSL rehearsal and namespace transcripts: unchanged. Neither
  reaches readiness (`mute` never signals), so neither is judged; a
  rehearsal is never judged by design.
- `src/expect.zig`: five unit tests — the board's derivation pinned
  line for line for a machine with a static network, a gateway, dns, a
  USER, a one-shot and a READY daemon; the two lenses differing on
  exactly two lines; a match across pids and readiness order; a line
  missing, a line unexpected, a line said twice; the wildcard and the
  literal `pid 1`. 11/11 with the rest.

## The law this pays for

A machine that cannot tell its own boot from another cannot be trusted
to commit an update. Now it can: the same text the author reads on the
console, the agent reads in the pinned transcript, and the machine
reads from its own image. Text before act reached the act.

---

# PRJ-2 — the consumer convicts what the diff could not: Ring's comment is '#'

The author said: run the projected `device.ring` through MicroRing. It
was refused on the first try, and the refusal is the point of this
entry.

```
Error (S1) In file: eval
In Line (11) Literal not closed
```

**Line 11 of the projection was a COMMENT** — and Ring's comment
character is `#`, not `--`. `--` is the machine language's, which is
Lua's, and I had carried it across without checking MicroRing's own
files (its template and every example open with `#`). Ring therefore
saw no comment at all, read the prose as code, and the apostrophe in
"the Device language's" opened a string literal that never closed.

**The judge could not have caught it.** `judge_project.sh` diffed the
projection against an expectation taken from the same generator: both
sides were wrong in the same way, and the court was green. Only the
CONSUMER could convict, and it did, in one line, the first time it was
asked. So the consumer is now part of the judge: after the diff,
`judge_project.sh` runs MicroRing on the projection when a binary is
found beside the repository, and says so when there is none.

With `#`, MicroRing accepts and runs the projected file unchanged:

```
[microring] pico2 . 2 pin(s) . 2000ms
[microring] done at 2000ms
```

Two pins and the declared board, read out of a file this repository
wrote from a `.machine` declaration. The expectation is re-pinned in
the same commit as the fix.

**The law this pays for:** a generated artifact is judged by the thing
that consumes it, not by a diff against yesterday's output of the same
generator. The transcripts have always had that property — QEMU is a
real consumer — and the projection did not until now.

---

# PRJ-1 — the edge profile projected: a MicroRing project, written and judged

Fourth and last of the four the author ordered on 2026-09-12, and the
only one that reaches into another repository's territory — so it was
read first: MicroRing's own templates, `Device()` seam and examples say
exactly what it consumes, and nothing here was invented.

## What MicroRing is owed, and what it owns

A MicroRing project IS a folder with a `device.ring` in it (its CLI
says so by refusing anything else), and that file holds one
`Device([...])` declaration: `:board`, `:pins` (each `[:gpio, :mode]`),
and the behaviour — `:every`, `:on`, `:parts`. The first two are
exactly what a `.machine` file declares. The behaviour is not, and this
repository does not invent it: it belongs to the **Device language**,
an L2 member of the alphabet, and until that exists the every/on
handlers are the author's own Ring code beside the generated file.

MicroRing's standing refusals are untouched: not an RTOS, not a new
language, the firmware and the tiers are its own. `harb project`
writes text and hands it over.

## What was built

- **The edge boards, fixture-first** (A15, R51, R52; A3 re-pinned as
  `machines/cold_room_sensor.machine` verbatim; **67/67**): each
  profile has its own board menu and its own emulator board — hosted
  keeps `qemu_pc`/`qemu_virt`/`rpi4`, edge gets MicroRing's own words,
  `sim` (its simulator, and the edge default), `pico2`/`pico2w` (tier
  2, its flagship) and `esp32c6` (tier 3). A board of the other
  profile is refused BY PROFILE, which is what R35 always meant; the
  earlier reading ("an edge machine names its board in its own
  substrate") was written before MicroRing had been read and is
  corrected here. `thumbv8m` joins the architectures, because the
  RP2350 is a Cortex-M33 and the fixture should not lie about it.
- **`harb project <file.machine> --out <dir>`** (`src/project.zig`):
  the `device.ring`, and a printed account of what did NOT cross over —
  the flash MOUNT (the substrate mounts it), the capabilities (the
  machine's envelope, which MicroRing has no gate for), each service's
  behaviour (the Device language's). The generated file carries the
  same account in its own comments, so it is legible where it lands.
- **Both refusals**: `harb project` refuses a hosted machine, and
  `harb image` refuses an edge one, each naming the other verb.

## What was measured

`machines/cold_room_sensor.device.ring.expected`, 20 lines, identical
under `experiment/judge_project.sh`. The projected file is real
MicroRing source: `Device([ :board = "pico2", :pins = [ :led = [ :gpio
= 25, :mode = :out ], :probe = [ :gpio = 4, :mode = :in ] ] ])`.

## Named seams

- The Device LANGUAGE itself (behaviour: every/on/parts as declared
  sentences rather than Ring code) — an L2 member, not this
  repository's to declare.
- `:parts` (a sensor's type, an ADC channel) has no seat in the machine
  language yet; a PART kind is a fixture-first widening when a real
  sensor needs it.
- Running the projection through MicroRing itself (`microring run`) on
  this host: MicroRing's desktop runtime is built and closed, so this
  is a real next step rather than a wish.

---

# USR-1 — a declared identity: a service stops being the machine

Third of the four the author ordered on 2026-09-12. Until now every
service ran as the machine itself, which is to say as root: a world
that only draws a kitchen display could rewrite the boot partition.

## What was decided

**An identity is declared, not looked up.** `DEFINE USER kds AS (UID
1000, GID 1000)` is a kind of its own, and a service names it with
`USER kds` — a reference resolved at check time like AFTER, so a
service running as a nonexistent identity is refused before any boot.
**uid 0 cannot be declared** (R47): root is the machine itself, so a
service that needs the machine's own powers is visibly the one with NO
user line, rather than one that asked for root. **GID defaults to the
UID**, the convention a small machine wants and one fewer number to
keep in step. **The image derives `/etc/passwd` and `/etc/group`** from
exactly the declared set plus root, with `/nonexistent` for every
shell, because a machine that has no shell should say so in its own
files.

## What was built

- The USER kind and the SERVICE seat, fixture-first (A14, R46–R50;
  **64/64 on the first run**), `machine.stzu` gaining the declaration
  (7 declarations now, accepted by stz's meta-court), the plan printing
  `-- as world (1000:1000)`.
- **PID 1 drops the credentials between fork and exec** (`src/init.zig`):
  `std.process.Child` has no seat for a uid, and the drop must happen
  in the one moment when the child is still ours and not yet the
  program's. So a service with an identity is forked by hand, does
  `setgid` then `setuid` — group first, because after `setuid` there is
  no privilege left to change the group with — and execs. A failure
  between fork and exec exits 126 or 127 rather than returning into
  init's loop with a second init in it.
- **`harb id`**, the witness: a machine has no coreutils, so the one
  binary answers `uid=N gid=N` from inside it.

## What was measured

`machines/qemu_hello.machine` declares `USER world` and a service that
runs `harb id` as it. The boot says both halves: `start whoami -- pid
N -- /harb id -- as world (1000:1000)` from PID 1, and `id: uid=1000
gid=1000` from the service. Pinned at **32 lines**, up from 28, in the
same commit as the seat. The other two machines and the rehearsal are
unchanged and judged identical.

## Named seams

- Supplementary groups, and a service's umask.
- The per-DEVICE identity (an Ed25519 key that never leaves the board)
  is a different thing from a per-service uid and is still queued.
- File ownership in the image: everything is still owned by root, so an
  identity can read what it is given and write only where the machine
  made a writable place (`/tmp`, a declared mount).

---

# ZIGCC-1 — the kernel built by our own compiler: four walls named, the tree builds, the image does not boot

Second of the four the author ordered on 2026-09-12. The architecture
table has said since OS-2 that `make CC="zig cc"` is the destination
and gcc was the stand-in. This measures it. **The answer is no, not
with zig 0.15.2** — and the four walls are named, two of them zig
defects worth reporting upstream.

## What was decided

A Linux zig is needed: the Windows one cross-compiles harb but cannot
drive `make` inside WSL. It is fetched ONCE and **pinned by digest**
(`experiment/zigcc_fetch.sh`, `vendor/zig/PIN.txt`, sha256 from
ziglang.org's own index), exactly as the kernel tarball and the board
firmware are. The experiment lives behind `HARB_CC=zigcc` on
`os2_image.sh`, in its OWN kernel tree per architecture, so the two
toolchains never share an object and the default stays gcc.

## The four walls, in the order they appeared

1. **`-mtune=generic` stops the first object.** zig cc parses
   `-march`/`-mcpu`/`-mtune` itself, into zig's own CPU model, and
   knows no CPU named "generic". Dropped in the wrapper: a scheduling
   hint, never a meaning.
2. **Unused arguments are errors.** zig cc makes
   `-Wunused-command-line-argument` an error and the kernel's assembly
   rule passes flags that phase does not consume.
   `-Wno-unused-command-line-argument` added.
3. **Assembly plus a dependency file produces NOTHING, and exits 0.**
   Asked for `-S` together with a depfile in either spelling
   (`-Wp,-MMD,P` or `-MMD -MF P`), zig cc writes the depfile, writes no
   assembly, and reports success; the kernel then stops at "cannot open
   devicetable-offsets.s". Isolated flag by flag on the kernel's own
   failing command (`zigcc_probe3.sh`). **A zig defect**, and the
   nastiest kind: silence with a zero exit. The wrapper splits it into
   two truthful passes — the assembly alone, then the preprocessor
   alone for the dependencies — and the depfile still lists every one
   of the hundred headers the source includes. Nothing forged.
4. **PIC is decided by the target and cannot be argued with.** Under
   PIC a symbol's address is not an immediate, so the kernel's per-CPU
   accessors fail with "invalid operand for inline asm constraint 'i'"
   — but on every LINUX target zig refuses `-fno-pic` outright ("the
   selected target requires position independent code"). Only zig's
   FREESTANDING target accepts it, and there the kernel's own sources
   compile clean, integrated assembler and per-CPU accessors included
   (`zigcc_probe6.sh`). So the wrapper sends non-PIC compilations to
   `<arch>-freestanding` and leaves PIC ones (the VDSO, a real shared
   object that asks for `-fPIC`) on the Linux target, where zig's
   requirement is exactly what the VDSO wants. Getting that division
   wrong shows up as "R_X86_64_32 against hidden symbol" at the VDSO
   link. Real mode asks for non-PIC in the third spelling, `-fno-pic`.

## What was measured

- **The tree builds.** After the four concessions: 478 options (gcc's
  configuration of the same fragment has 483 — the kernel's own Kconfig
  differs for clang), **bzImage 1,446,912 bytes in 1m40** at two jobs
  (gcc: 1,217,536 bytes, 78 s).
- **The image does not boot.** Under QEMU it prints nothing at all —
  not even `earlyprintk` from the decompressor, which speaks before any
  console exists (`zigcc_boot_diag.sh`). It dies in the 16-bit setup
  code, the part this wrapper pushed onto a target the kernel never
  intended.

## The verdict, and the claim narrowed

gcc keeps building the kernel of every image. The architecture table no
longer says `zig cc` builds it; it says gcc does, that zig cc was
attempted on this date, and where it stopped. A compiler that produces
an unbootable image is not a sovereignty gain, and saying otherwise
would be the kind of claim this repository exists to refuse.

What is kept: the instrument, whole — `zigcc_fetch.sh` (pinned),
`zigcc_wrapper.sh` (every concession stated in its own comments),
`zigcc_kernel.sh`, the six probes, and `HARB_CC=zigcc` in the image
pipeline. A later zig, or an `LLVM=1`-shaped attempt with lld and the
LLVM binutils, starts where this stopped rather than from nothing.

## Named seams

- The 16-bit setup code is the suspect: the freestanding target is a
  poor fit for `-m16 -march=i386`. A next attempt should keep the
  kernel's own target and find another way past the PIC requirement
  (a zig that allows `-fno-pic` on Linux targets would end it).
- `ld.lld` is not a zig subcommand, so a full LLVM build is not
  reachable through zig alone; the linker and binutils would stay the
  distribution's in any case.
- **The estate's own mirror of the kernel tarball** is a ROUTED ERRAND,
  not done: 148 MB exceeds a git file limit, so availability needs
  storage the author picks (a private release asset, a bucket, a second
  machine). Integrity is already sovereign — the digest is pinned and
  verified on every fetch — and this errand is about availability only.

---

# RDY-1 — a daemon's own word: READY, and the hole it closes in the A/B trial

Ordered by the author on 2026-09-12 ("take whatever decision you think
suitable on my behalf, and then do the tasks in the order you
suggested"), first of four. The decisions taken, and open to reversal:
**the signal is a file**, not a socket — any program in any language
can create a path, and it is visible from outside; **there is no
timer** — a timer would race a boot, while a wait does not, and a box
that will not commit an update whose world never came up is behaving
correctly; **READY is refused on a one-shot**, whose readiness is
already its exit 0; **the court is the rehearsal**, where a live
daemon is natural and no kernel is needed.

## The hole it closes

AB-1 left a daemon ready the moment it was SPAWNED. The box's real
worlds will be daemons, so under that rule an A/B trial could commit
itself while the kitchen display was still opening its socket — an
update judged good by a machine that had not yet served anyone. The
commit condition is `every service is ready`; giving a daemon a way to
say when that is true closes it without touching the commit rule.

## What was built

- **`READY "<path>"`** on SERVICE, fixture-first (A13, R43, R44, R45;
  **58/58 on the first run**): the absolute path the service creates
  when it is serving. Refused on a one-shot, refused if not absolute,
  and one path signals for one service. `machine.stzu` gained the seat
  (counts unchanged: it is a seat, not a kind).
- **PID 1 waits for the word** (`src/init.zig`): a daemon with READY
  is ready when the path appears, never before; the reaper polls for
  it a quarter second at a time, prints `boot: <name> -- ready
  (<path>)` when it comes, and starts what waited. A daemon that never
  signals never becomes ready: its dependents never start, are named
  at the end (`what it comes AFTER never signalled ready`), and the
  A/B commit never happens.
- **The instrument names what it cut short**: with `--turns`, the run
  now also prints each service still waiting and why, so the negative
  case is read off the transcript instead of inferred from silence.
- **The image gives the signal a home**: the parent directory of each
  READY path joins the initramfs (the root is RAM and writable, so a
  directory is all the image owes it).
- **The rehearsal is the court** (`machines/wsl_rehearsal.machine`):
  `signals` is a daemon stand-in that creates its path and stays alive
  (`flock <path> sleep 30` — creating the path IS what flock does
  before running its command), `after_signals` starts on the signal;
  `mute` runs and never signals, `after_mute` never starts. The script
  removes both paths before each run: a stale signal would make a
  daemon ready before it ever started.

## What was measured

- The rehearsal and the namespace PID 1: `signals -- ready
  (/tmp/harb-signals.ready)` followed by `start after_signals`, and
  at the end `after_mute has not started -- what it comes AFTER has
  not signalled ready`. Both sides print.
- The three images unchanged and judged identical: 28, 22, 49 lines.
  None of them declares READY yet — the box's worlds are stand-ins
  that exit, so they are one-shots — which is why the pins did not
  move. When the real worlds arrive as daemons, they declare READY and
  the pins move with them.

## Named seams

- A bounded window for a trial (deliberately not a per-service
  timeout): if the box should give up on an update after some minutes,
  that belongs to the trial, not to the service.
- Health beyond "it said it was serving": a health seat, and the
  question of whether a signal should be withdrawn when a world stops
  serving without exiting.

---

# AB-1 — two slots: an update is a trial before it is a commitment, and the card is the witness

Ordered by the author on 2026-09-12 ("start them in order one by one",
second: A/B slots with watchdog rollback).

## What was built

- **`SLOTS "<device>"`** on MACHINE, fixture-first (A12, R41, R42;
  54/54): the boot partition that holds `config.txt` and two slots.
  Needs a board whose firmware can try a slot (`rpi4`); the emulator
  boards load the kernel directly and are refused by name. The plan
  carries a `slots` step; `makeen_box.machine` declares
  `SLOTS "/dev/mmcblk0p1"`.
- **The card's layout** (`src/image.zig`): `slots/A/` and `slots/B/`
  each hold `kernel8.img`, the dtb, `initramfs.cpio` and a
  `cmdline.txt` carrying `harb.slot=A|B`; `config.txt` names the
  committed slot in `os_prefix` and, under the firmware's own
  `[tryboot]` filter, the other. The same image fills both slots at
  first.
- **PID 1's slot logic** (`src/init.zig`): after the mounts it reads
  which slot booted (`harb.slot=` on `/proc/cmdline`), mounts the
  boot partition, reads which slot is committed, and says whether this
  boot is steady or a trial. It arms the hardware watchdog by opening
  `/dev/watchdog`, feeds it from a polled reaper loop (a quarter
  second between looks), and on a trial COMMITS — rewriting
  `config.txt` so the two prefixes swap, synced — only once every
  service is READY (a one-shot exited 0, a daemon spawned): a
  one-shot that fails, or a service its failure held back, keeps the
  trial uncommitted and the rollback is the answer. A steady boot
  commits nothing. The magic close
  disarms the watchdog before a clean restart. `--hold` is the
  rollback instrument: never commit; with a watchdog armed, stop
  feeding it and let the hardware answer; without one, restart as any
  uncommitted trial ends.
- **`harb update <dir>`** (`src/update.zig`): the file half — read the
  committed slot from `config.txt`, refuse unless every file of the
  new image is present, write the OTHER slot, sync — and the reboot
  half, a restart with the argument `0 tryboot`. `--boot <dir>`
  rehearses the file half on any directory; `--no-reboot` stops after
  writing. Rehearsed on the host with its negative (a missing file
  refuses before a byte is written).
- **The judge**, doubled: after the trial boot the script reads
  `config.txt` back from the card image; then boots a PRISTINE copy of
  the card with the trial held and reads that card back too. Both
  readings are lines of the pinned transcript.

## What was measured

- The trial boot under `raspi4b`: `slot B -- a trial (committed is
  A)`, the worlds run, **`slot B -- committed: every service is
  ready; config.txt now boots B, A is the fallback`**, and the card
  read back says `os_prefix=slots/B/` first. The held trial on the
  pristine copy: the same trial, `held, not committed`, a restart,
  and that card still says `os_prefix=slots/A/`. Pinned, 49 lines.
- `harb update` on a fake boot partition: slot B written (four
  files), `config.txt` untouched; with `cmdline.txt` removed, refused
  whole.

## What was found

1. **QEMU's raspi4b resets the board the moment the watchdog is
   armed.** Its power-management model has no countdown and reads the
   driver's "full reset on expiry" bit as "reset now"; the first trial
   boot vanished after the capability lines with its buffered output,
   and the card was unchanged. The emulator's boot line now carries
   `harb.watchdog=off` (never the card's `cmdline.txt`), PID 1 states
   that a trial cannot roll back by hardware there, and everything said
   before arming is flushed first, so a board that resets on arming can
   never take the transcript with it.
2. **mtools asks on stdin when a name clashes.** `mmd` on a directory
   that already existed opened its interactive clash prompt on a pipe
   that never closes; the card assembly hung thirty-three minutes.
   Every mtools call now runs with `-D s` or `-D o` and stdin from
   `/dev/null`; `wsl_cleanup.sh` ends what it left behind.
3. **The held trial must run on a pristine card.** The first hold ran
   on the card the trial had just committed, so it was steady, not a
   trial, and the instrument measured nothing. The card is copied
   before any boot writes to it.
4. **Mainline's watchdog driver ignores the restart argument**, so
   `0 tryboot` is a plain restart on this kernel: the firmware's
   tryboot flag cannot be raised from it without a patch to
   `bcm2835_wdt.c`. The file half of an update is complete; the
   one-shot trial request is the board's first task.
5. **A half-written slot is refused before it is written.** The
   rehearsal's negative left three files behind; every source is now
   checked first.
6. **Committing on "started" raced the transcript**: the commit line
   landed between the last one-shot's output and its exit, on timing.
   Committing on "ready" (exited 0 for a one-shot) is both the
   deterministic order and the right rule: a failed one-shot never
   commits.

## Named seams

- The tryboot flag: a vendored patch to the watchdog driver (parse
  the restart argument, set the flag in `PM_RSTS`), done with the
  board and the firmware documentation in hand.
- Health beyond "every service started": a health seat, and a bounded
  window for a trial.
- The hardware watchdog's real countdown, on the board.

---

# NET-1 — the NETWORK kind: a machine declares its wire, PID 1 brings it up, a lease judged in the emulator

Ordered by the author on 2026-09-12 ("start them in order one by one",
the NETWORK kind first), while the hardware for OS-5 is on its way.

## What was built

- **`DEFINE NETWORK`**, fixture-first (A10, A11, R36–R40; 51/51 on the
  first run): `INTERFACE`, `ADDRESS dhcp | "a.b.c.d/n"`, and for a
  static address `GATEWAY` and `DNS`. One network per interface; the
  `network` capability must be granted; a dhcp network may not declare
  what it learns; addresses are parsed at check time. `machine.stzu`
  gained the declaration and a `server` form (6/5/0/3, accepted by
  stz's meta-court). The plan carries a `network` step after the
  capabilities and before the services.
- **PID 1 brings the networks up** (`src/netcfg.zig`), like mounts,
  before any service: static through four ioctls and a fifth for the
  default route (`SIOCADDRT` with the kernel's `rtentry`, laid out by
  hand — the stdlib has no such table); dhcp through a client written
  here: DISCOVER, OFFER, REQUEST, ACK on a broadcast UDP socket bound to
  the interface, three tries of three seconds, the lease's address,
  mask, router and DNS applied. Every result is one transcript line.
- **`harb net`** by hand does the same: `<iface> <cidr> [gateway]` or
  `<iface> dhcp`.
- **The emulator's oracle**: when a machine declares a NETWORK, the
  image gives `qemu_pc` and `qemu_virt` a virtio NIC on QEMU's
  user-mode network (`-netdev user`), whose built-in server leases
  `10.0.2.15` with router `10.0.2.2` and dns `10.0.2.3`. The kernel
  fragment gains the IP stack and the NIC. The Pi has GENET already.
- **The box's file**: `makeen_box.machine` declares `NETWORK lan` static
  at `192.168.10.1/24`, no gateway (the box is the gateway), and the
  `network_up` service is gone; `makeen_qemu.machine` declares
  `ADDRESS dhcp`.

## What was measured

- `makeen_qemu` on `virt`: **the lease on the first try** —
  `network lan -- eth0 up 10.0.2.15/24, gateway 10.0.2.2 (dhcp), dns
  [10.0.2.3]`, then both worlds; pinned, 22 lines. The kernel gained
  the IP stack and virtio-net: 2m40 for the rebuild.
- `makeen_box` under `raspi4b`: the static network refused `NODEV` (no
  Ethernet in the emulator), the worlds now run since a refused network
  holds nothing back; pinned, 21 lines. `qemu_hello` unchanged, 28.

## What was found

1. **A NETWORK is a mount, not a service.** OS-4 had the box bring its
   interface up through a `network_up` service, and the worlds came
   AFTER it, so in the emulator they never started. Declaring the wire
   as a kind of its own puts it where a mount is: before the services,
   stated, and not a gate. The worlds now run in both emulated boxes.
2. **The kernel's route ioctl takes a struct the Zig stdlib does not
   carry**: `rtentry` is laid out by hand from the uapi header, 64-bit
   fields and padding included. The emulated lease sets a default route
   through it and the kernel accepted it; on a machine where the route
   already exists `EEXIST` is treated as success.
3. **QEMU's user-mode network is a complete oracle for dhcp**: a
   deterministic lease with no hardware, and the transcript pins it.

## Named seams

- Lease renewal (the box takes its address once, at boot), a DNS
  resolver, the box as a DHCP SERVER for the phones, IPv6.
- A readiness signal for daemons; `RESTART always` worlds in
  `makeen_box.machine` once the real worlds are daemons (the stand-ins
  exit, so they are `never` today).

---

# OS-4 — the real box: a Raspberry Pi 4, its SD card image, and the same board emulated to judge it

Ordered by the author on 2026-09-12 ("choose the board on my behalf and
go for OS-4"). The board ruling is in `doc/PROVENANCE.md`
(STZ-OS-BOARD-01): the Raspberry Pi 4 Model B.

## What was built

- **The BOARD clause**, fixture-first: `qemu_pc`, `qemu_virt`, `rpi4`,
  defaulting by ARCH, hosted-only, coherent with ARCH; A9, R33, R34, R35
  are the board's own, A1/A3 carry the defaults, A2 is
  `machines/makeen_box.machine` verbatim with `BOARD rpi4`. **44/44**;
  the court convicted the implementation once on R35 (the ARCH check
  ran before the profile check; reordered, the fixture kept).
  `machine.stzu` carries the seat; the plan and the init print the board.
- **`harb net <iface> <a.b.c.d>/<n>`** (`src/net.zig`): a role of the one
  binary — four ioctls on a datagram socket, every result stated, no
  DHCP, no gateway, no DNS. The box's `network_up` service is now a
  program that exists: `RUN ["/harb", "net", "eth0", "192.168.10.1/24"]`.
- **The rpi4 target** (`src/image.zig`): the arm64 kernel with the
  BCM2711 platform, the mini-UART and PL011, the mailbox and firmware
  driver, the watchdog (which is also how the board restarts), SDHCI
  for the card, GENET for Ethernet; the device tree
  `bcm2711-rpi-4-b.dtb`; two consoles (`ttyAMA0` for the emulator's
  PL011 on the header pins, `ttyS1,115200` for the board's mini-UART
  there); `sd.list` (the card's partitions and the boot partition's
  files), `config.txt` and `cmdline.txt` written by the derivation.
- **Two device trees from mainline's, both derived** (`DTB_OPS` and
  `QEMU_DTB_OPS` in `image.env`, applied by `experiment/dtb_ops.py`,
  every op printed): the CARD's tree adds the mmc aliases mainline
  lacks, so `/dev/mmcblk0p2` is a fact and not a probe-order race; the
  EMULATOR's tree disables the two AON blocks QEMU does not model and
  opens the legacy SDHCI where QEMU plugs the card, aliased as mmc0 so
  the declared device name holds in both worlds.
- **The SD card image** (`experiment/os2_image.sh`): a 256 MiB card
  (QEMU wants a power of two), p1 FAT32 64 MiB with the firmware's
  `start4.elf`/`fixup4.dat` (raspberrypi/firmware, tag `1.20260907`,
  pinned by sha256 in `vendor/rpi-firmware/PIN.txt`, gitignored),
  `config.txt`, `cmdline.txt`, `kernel8.img`, the card's DTB, the
  initramfs; p2 ext4 64 MiB, the declared `/data`. `sd.img` is what a
  card gets `dd`'d with.
- **The judge**, unchanged: the same board under QEMU `raspi4b`, the
  transcript against `machines/makeen_box.expected`.

## What was measured

- arm64 kernel for the board: 689 options, `Image` 5.6 MB, **2m50** wall
  at two jobs for the first build; the card 256 MiB; the initramfs
  4.4 MB.
- Boot under `raspi4b` (QEMU 10.2 TCG): `Machine model: Raspberry Pi 4
  Model B`; PID 1; `proc` `sysfs` `devtmpfs` done; **`mmcblk0: p1 p2`,
  `ext4 at /data -- done`** on the card's second partition by its
  declared name; `gpio` refused as declared; `network_up` ran `harb
  net eth0` and got **`no such interface (NODEV)`** — QEMU disables
  GENET itself, the emulator has no Ethernet — so `kds` and `poste`
  **never started** by the readiness rule, named; `reboot(RESTART)`
  through the BCM2835 watchdog; QEMU exit 0. Pinned, 17 lines: the
  emulator's truth. On the board, Ethernet exists and the worlds start;
  that difference is OS-5's first finding, expected and stated.

## What was found

1. **QEMU's raspi4b faults on the AON block.** The first boot printed
   nothing: `brcmstb_l2_intc_of_init` took a synchronous external abort
   at 0x7ef00100 (the AON L2 interrupt controller); with it disabled,
   `clk_disable_unused` took the same abort in `clk_gate_readl` on the
   DVP clock at 0x7ef00000. Found with `earlycon=pl011,mmio32,0xfe201000`,
   `initcall_debug`, and `System.map` (tinyconfig has no KALLSYMS;
   `experiment/os4_syms.sh` resolves the addresses). QEMU disables pcie,
   rng, thermal and genet on its own; these two it misses. Both are
   named in the emulator's tree and nowhere else.
2. **QEMU plugs the card into the legacy SDHCI**, not into emmc2 where
   the board's card sits; mainline gives that host to the Wi-Fi SDIO
   (non-removable, with a power sequence). The emulator's tree opens it
   as a plain removable host. `mmc0: SDHCI controller on fe300000.mmc`,
   `mmcblk0: mmc0:2804 QEMU! 256 MiB`.
3. **Mainline's rpi-4-b tree has no mmc aliases**, so the card's index
   is probe order once the Wi-Fi host probes too. The board's tree pins
   `mmc0` to emmc2. A declared device name must be a fact.
4. **The mini-UART driver hides behind two menus** (`SERIAL_8250_EXTENDED`,
   `SERIAL_8250_SHARE_IRQ`); the build's dropped-option check named it.
5. **QEMU's SD model wants a power-of-two card**; the first 130 MiB
   image was refused. 256 MiB, partitions at the front.
6. **The Bash tool cannot pass `$` or `&` through `wsl.exe`** in a
   one-line `bash -c`; every WSL act is a script file.

## Named seams

- The board itself: this card has not touched a Pi. The first real boot
  will differ from the pin where the emulator lacks the hardware
  (Ethernet, the AON block) and nowhere else, or that is a finding.
- The Wi-Fi firmware blob (not taken); DHCP, gateway, DNS (the NETWORK
  kind); A/B slots with watchdog rollback (the watchdog driver is in);
  `make CC="zig cc"`; the judge into `harb judge`.

---

# OS-3 — the Makeen box: the aarch64 image, a persistent partition, and AFTER made deterministic

Ordered by the author on 2026-09-12 ("take decision on my behalf on the
waiting rows, and then go for OS-3, the aarch64 image for the Makeen
box"). The three rulings are in `doc/PROVENANCE.md` ("The rulings of
2026-09-12"); the mailbox is `softanza/mailbox/harb.md`.

## What was built

- **`harb image` for aarch64**: one `Target` table per architecture
  (kernel ARCH and cross prefix, the kernel artifact, the QEMU machine,
  the console, the serial and block kconfig, the virtio transport —
  virtio-mmio on `virt`, virtio-pci on `pc`). The derivation now emits
  `image.env` (what the build must be told, written from the
  declaration alone before any staging check) and `disk.list` (the
  block devices the declared mounts need; one per image today, a
  second is refused by name). The boot line carries the virtio disk.
- **`experiment/os2_image.sh` made arch-aware**: one kernel tree per
  ARCH under `$HOME`, the cross compiler from the derived prefix, the
  kernel artifact by its derived path, the disks made with `mkfs` from
  `disk.list`, and a check that every option the fragment asked for
  survived `olddefconfig` — a dropped one is named as a missing
  dependency.
- **`machines/makeen_qemu.machine`**: the Makeen box as QEMU's `virt`
  can carry it — aarch64, the PL011 console, a 64 MB ext4 disk at
  `/data` on `/dev/vda`, the `kds` and `poste` worlds as stzr services.
  `makeen_box.machine` (fixture A2) stays the box's own truth with its
  SD-card partition and its network service; the two converge when the
  box is real.
- **stzr for aarch64**: stz's runtime cross-built for aarch64-linux-musl
  (764 KB static) with one flag; the toolchain in WSL gained
  `gcc-aarch64-linux-gnu`, `qemu-system-arm`, `e2fsprogs`.
- **AFTER waits for readiness** (`src/init.zig`): a one-shot (`RESTART
  never`) is ready when it has exited 0, a daemon (`always`,
  `on_failure`) as soon as it is spawned; a one-shot that fails blocks
  its dependents for good and init names them (`never started -- it
  comes AFTER x, which exited 1`). Services start when eligible, from
  the reaper loop, in plan order. `GRAMMAR.md` carries the rule.

## What was measured

- arm64 kernel: 531 options, `Image` 3,768,328 bytes, **2m01 s** wall at
  two jobs for the first build (3m27 user), 27 s for the reconfigure.
- Boot on `virt` (cortex-a53, 512 MB, TCG): PID 1, `proc` `sysfs`
  `devtmpfs` done, **`ext4 at /data -- done`** on the virtio disk,
  `gpio` refused as declared, `kds` read the machine file that rode in
  the image (7 declarations), `poste` started only after `kds` exited 0,
  both exited 0, `reboot(RESTART)`, QEMU exit 0. Pinned:
  `machines/makeen_qemu.expected`, 20 lines.
- x86 re-judged under the readiness rule: `hello` now starts after
  `self` exits, the transcript is deterministic; `qemu_hello.expected`
  re-pinned in this commit for that named reason (28 lines).

## What was found

1. **`init=` was the wrong parameter and x86 booted by accident.** The
   root IS the initramfs; with `init=` the kernel looks for `/init`,
   finds none, and goes to mount a root DEVICE. The x86 kernel had no
   block layer, so `mount_root` did nothing and the boot proceeded; the
   arm64 kernel had `CONFIG_BLOCK` for its ext4 mount and panicked
   `VFS: Unable to mount root fs on unknown-block(0,0)`. `rdinit=` is
   the honest parameter and both machines boot with it.
2. **Menus tinyconfig closes drop the fragment's drivers silently.**
   `CONFIG_VIRTIO_BLK=y` and `CONFIG_VIRTIO_MMIO=y` vanished under
   `olddefconfig` because `VIRTIO_MENU`, `BLK_DEV` and `BLOCK` were off;
   the mount failed `NOENT` with no other symptom. The fragment now
   names the three, and the build prints every requested option that
   did not survive.
3. **AFTER only ordered spawns**, and the x86 judge caught it on the
   third boot (the exit lines of `self` and `hello` swapped). The
   readiness rule replaces it; both expectations were re-pinned in the
   same commit as the rule, for that stated reason.
4. **`reboot(RESTART)` inside a pid namespace ends the namespace**: the
   kernel sends the namespace's init SIGHUP instead of rebooting, so the
   WSL PID 1 transcript stops at the `init halts the machine` line and
   `unshare` exits nonzero. The kernel's rule, not a defect; the init's
   comment says so.

## Named seams

- The real box: a board's kernel config and device tree, U-Boot, the SD
  card's partitions (`makeen_box.machine` names `/dev/mmcblk0p2`), A/B
  slots with watchdog rollback.
- The NETWORK kind (`network_up` in A2 names a program that does not
  exist); the USER seat.
- `make CC="zig cc"` for both kernels; a tarball mirror in the estate.
- The judge into `harb judge`; one virtio disk per image today.

---

# OS-2 — the machine boots: a vendored kernel, an image derived from the plan, QEMU, the transcript judged

Ordered by the author on 2026-09-12 ("install qemu, gcc and make in WSL
and go for OS-2"), the same day as OS-1.

## What was built

- **`harb image`** (`src/image.zig`): from a judged plan, three texts
  and no toolchain — `initramfs.list` in the kernel's own gen_init_cpio
  format (device nodes for PID 1, the mount points, `/harb`, every
  program and file the services name taken from a staging root and
  REFUSED if absent, the declaration itself at `/etc/machine`),
  `kernel.fragment` (the kconfig the profile and the declared mounts
  need, merged over tinyconfig), `boot.cmd` (the QEMU line). Hosted and
  x86_64 only today; the rest refused by name.
- **The init's ending** (`src/init.zig`): PID 1 may not exit, so when
  every service has ended it calls `reboot(RESTART)`; under QEMU
  `-no-reboot` that closes the boot and the transcript. In a user
  namespace the kernel refuses it and the transcript says so.
- **The vendored kernel**: Linux 6.12.109 LTS, pinned by digest from
  kernel.org's own `sha256sums.asc` (`vendor/PIN.md`,
  `experiment/os2_kernel_fetch.sh`); the tarball stays out of git (over
  the file limit) and in `vendor/linux/`.
- **The imperative half** (`experiment/os2_image.sh`, WSL Ubuntu):
  stage, derive, tinyconfig + fragment + olddefconfig, `make -j2
  bzImage`, gen_init_cpio, QEMU with the serial console captured, then
  the judge: the transcript normalised (firmware banner and control
  bytes before PID 1's first line, CRs, pids → N) and diffed against
  `machines/qemu_hello.expected`.
- **stzr in the image**: stz's runtime cross-built from `D:\GitHub\stz`
  for x86_64-linux-musl (static, 776 KB, ReleaseSmall) with one flag —
  the first time the Softanza runtime ran on a machine the estate
  declared.

## What was measured

- Kernel: 496 options on, bzImage 1,217,536 bytes, **78 s wall** at two
  jobs (2m08 user) on WSL Ubuntu, gcc 15.2.
- Image: initramfs 4,232,704 bytes — harb 3.4 MB unstripped, stzr
  776 KB, hello.luau, the machine file.
- Boot (QEMU 10.2, TCG, 256 MB): PID 1, `proc` `sysfs` `devtmpfs`
  `tmpfs` all mounted (`done` × 4 — the namespace refusals of OS-1 were
  the namespace's, not the init's), `self` (pid 15) printed the
  machine's own plan from inside the image, `hello` (pid 16) printed two
  lines from Luau under stzr, both exited 0, `reboot(RESTART)`, QEMU
  exit 0. **The transcript matches the pinned expectation line for
  line, 28 lines**, on the second run (the first run IS the pin, stated
  as such: there was no earlier oracle for a machine that had never
  booted).

## What was found

1. **Port 80 is blocked on this network**: apt over http timed out on
   every mirror address while https answered 200; the toolchain script
   switches Ubuntu's sources to https. `Acquire::ForceIPv4` was a wrong
   first diagnosis (the addresses shown were IPv6, the cause was the
   port).
2. **Extracting the kernel onto the Windows mount took longer than the
   600 s tool budget** and the build there would have been slower
   still; the pipeline extracts and builds in `$HOME` inside WSL, and
   the 1.6 GB stray extraction on the mount was removed.
3. **AFTER orders starts, not completions**: `hello` started after
   `self` was spawned, and the two outputs interleave under the
   scheduler. A completion/readiness seat is a fixture-first widening
   (`doc/ARCHITECTURE.md` §7).
4. **The Bash tool rewrites `/mnt/d/...` paths** handed to `wsl.exe`;
   WSL scripts are invoked from PowerShell.

## Named seams

- aarch64 image and real hardware (the Makeen box); block devices and
  persistent mounts (virtio-blk first); A/B slots; the bootloader.
- `make CC="zig cc"` for the kernel; a tarball mirror in the estate.
- The judge lives in a shell script today; folding it into `harb
  judge <name>` (portable, like the court) is queued.

---

# OS-1 — the declared machine: language, plan, and PID 1

Ordered by the author on 2026-09-12: a distinct private repository for
the operating layer, designed and built in the Softanza style. This
section records what was done, what was measured, and what was found.
Newest section first, as stz's PROTOCOL.md.

## What was built

- **The machine language v0.1** (`declarative/machine/GRAMMAR.md`):
  five kinds — MACHINE, SERVICE, CAPABILITY, MOUNT, PIN — over the
  Grammar Commons' lexical form, every menu closed, the capability
  vocabulary stzlib's nine names verbatim. Judged by `fixtures.json`:
  8 accepts with structural expectations (identity, counts, service
  order, granted set, folded rationale), 32 rejects each carrying the
  fragment its refusal must contain. **40/40** after one correction
  (below). Pinned in `PINNING.md`.
- **The language declared in stzu** (`machine.stzu`) and judged by
  stz's own meta-court through `experiment/judge_machine_stzu.luau`,
  run by stz's runner from stz's directory: accepted first run —
  5 declarations, 4 forms, 0 expressions, 3 refusals, verbs
  CAPABILITY MACHINE MOUNT PIN SERVICE. Nothing forked.
- **The parser and checks** (`src/machine.zig`), **the plan**
  (`src/plan.zig`: console, implicit mounts, declared mounts, every
  capability granted or refused, pins, services in AFTER order with
  declaration order breaking ties), **the court** (`src/court.zig`),
  **the init** (`src/init.zig`: mounts by syscall with each result
  stated, services spawned as argv, PID 1's reaper with the three
  restart policies), and **the CLI** (`src/main.zig`), one static
  binary.
- **Two Linux targets by one flag** (`zig build cross`:
  x86_64-linux-musl and aarch64-linux-musl, static, ~3.4 MB unstripped).

## What was measured

- The court, probed in fresh processes with a mutated judge before its
  scoreboard was believed: a wrong count on A2 → red (`expected 99 got
  3`); a wrong fragment on R5 → red (`refused for the wrong reason`); a
  valid source posing as a reject → red (`accepted as machine 'hello'`).
  Three reds, each for its named reason, exit 1.
- The init on Windows: refuses by name (`init is a Linux act; this
  binary was built for windows`), exit 2.
- The init under WSL Ubuntu, x86_64 static binary run from the Windows
  mount (`experiment/wsl_boot.sh`, transcripts in `zig-out/wsl/`):
  1. from an ordinary pid without `--rehearse`: refused (`init is PID
     1's act; from pid N pass --rehearse`), exit 2;
  2. `--rehearse --turns 8`: the three mounts narrated and not executed,
     `once` exited 0 and stayed down, `flaky` exited 1 and was restarted
     five times then given up on, `steady` exited 0 and was restarted;
  3. **PID 1 for real** inside `unshare -Urpf --mount-proc`: pid 1,
     children pids 2–10, `proc` mounted (`done`), `sysfs` and `devtmpfs`
     refused by the kernel with `PERM` (a user namespace's rule, stated
     not hidden), the same reaper behaviour, ending `init would now halt
     the machine`.

## What was found (each a finding, not a footnote)

1. **The court's first conviction was of its own implementation.** R20
   expected the fragment `no declaration grants gpio`; the refusal said
   `needs gpio, which no declaration grants`. Same meaning, wrong
   words: the G8 gate fired exactly as designed. The message changed,
   the fixture did not.
2. **Zig 0.15's `File.Writer` writes positionally on a seekable
   stdout.** The first WSL transcript had run 2's refusal overwriting
   run 1's header and the shell's `exit` lines spliced mid-sentence:
   with stdout redirected to a regular file, the buffered writer began
   at offset 0 and `pwrite` over what the shell had already appended. A
   console is a character device and never shows it; a redirected
   transcript always does. Fixed by the streaming writer; recorded in
   CLAUDE.md as a trap.
3. **WSL output cannot be read through the PowerShell tool** (UTF-16
   decoding drops and splices lines), and a multi-command `bash -c`
   cannot be quoted through `wsl.exe` from PowerShell. The script
   writes files on the Windows mount; the session reads the files.
4. **Silence is refusal held up at the machine's altitude**: a service
   needing a capability no declaration mentions is refused at check
   time (R17), which is stzlib's `stzSystemScope` down-constrain law
   with the machine as the target.

## Named seams (stated, not hidden)

- The image (kernel + initramfs) and the QEMU boot: OS-2, blocked on a
  Linux build environment on this host.
- NETWORK as a kind; USER as a seat; restart backoff and budget; kernel-
  level enforcement of refused capabilities per service.
- The edge boot through MicroRing's substrate; the touch build.
- The name (`doc/PROVENANCE.md`).
