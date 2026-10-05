# machine v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
02a61b456054e9c49c100da002e628597cd940a70687a738e3035b2b21c71829
```

(Before the STATE seat of 2026-10-05 (OWN-1):
`0c3bde455a1dc04c516359371344fdc918924055da8ad96217fcf5e0574fa785`,
132/132; the widening added A30-A35 and R104-R138 -- a world that runs
as an identity owns the directories it names and nothing else of the
machine's: only an identity can own one (R104), in a plain absolute path
of bounded length (R105-R110, R137, R138), only where the machine can
hand one over -- under /run, or inside an ext4 or tmpfs mount that world
keeps, with every mount above it kept too, and that is not read-only
(R111-R118, R133, R136) -- never the place itself, no two worlds owning
overlapping directories (R119-R121), a world's signal a plain path
sitting directly in its own directory and never in root's /run or a
neighbour's (R122-R124, R128, R129, R132), and the floor's own key and
record, named in plain paths, in no directory a world owns (R125, R126,
R130, R131); STATE is a clause of a service, by the clause menu (R127);
and two rules about mounts, because a directory's holder is the
innermost mount only if the outer one is declared first and no two share
a mount point (R134, R135). The first 24 of these (R104-R127) were the
seat as built; the other eleven rejects and two accepts are what an independent read-only review
of it found, each a spelling or an order the first rules did not see.
Before the FORWARD seat of 2026-10-04 (FWD-1):
`197fb6ee952b45e9249802bd060fe6e72e2a49a8f55661f998a478d6e8e66492`,
120/120; the widening added A27-A29 and R95-R103 -- a machine says it
is the way between its networks, never assumes it, and is refused it
where there is nothing to be the way between (an edge machine, one
network, none, a loopback beside one wire), and a machine that
forwards cannot say EGRESS none for a link it joins; a ROUTE is the fleet's
kind and is refused in a machine file by name (R102); and one machine
answers for a domain once (R103). Before the CONSOLE seat of 2026-09-28 (CON-1):
`03b94b47d81cf13b119df0c8bd47e74840d402531451a568e3fe70f20a7a5741`,
114/114; the widening added A25, A26 and R91-R94 -- a hosted machine's
CONSOLE is a port its board HAS, because the boot line now follows it:
a PC's four serial ports, the ARM emulator's one PL011, the Pi's
mini-UART on the header pins; saying nothing is the kernel's own
/dev/console, on every board.
Before the EGRESS ruling of 2026-09-27 (STZ-OS-RULING-06):
`f26bdc087e85393f33058b3c7f907d8729e97e282db227bd91a00a3c8ac311ce`,
110/110; the widening added A24 and R88-R90 -- a list whose
destinations cover every address is refused however it is spelled,
and half the space is still a perimeter.
Before the RETIREMENT seat of 2026-09-26 (RET-1): the file hashed to
`4c6aef6163840094...`, 107/107 -- and that digest was NEVER PINNED. The
rename of 2026-09-20 changed fixture A3 (`stzos project` became `harb
project` inside the cold-room sensor's own comment) and left
`4ed7adee6a389edbc6623bdf5b559fd4e87c5a1bcc0c9a9e40671116cbd828c1`
here, the file as it stood before the rename, for six days and every
green court between them. Nothing compared the two. The court does now,
before it judges a single case (PIN-1), and its first verdict was on
this. RET-1 added R85-R87: a FLEET, a MEMBER and a RETIREMENT each
refused in a machine file, which the fleet grammar had claimed since
FLT-1 and no fixture judged.
Before the TASKS seat of 2026-09-14 (THR-1):
`c6b02508f3650354c75149918876ffaa8659c8e0bcb7bb1316a677b1d6610d56`,
104/104; the widening added A23, R83 and R84, and gave SERVICE its
`TASKS`. Before the SEES seat of 2026-09-14 (SEE-1):
`a3f0d91ab47704acf1a966c3fcdf37df6ce01543dee8bdfadb162caad5ab7727`,
98/98; the widening added A22 and R78-R82, and gave SERVICE its
`SEES`. Before the NAMES seat of 2026-09-14 (NAM-1):
`b41640da56e91a49e0a9d98e60d661ed19adfbaf4da223895c67e2b7b1a1b395`,
89/89; the widening added A21, the `PEER` kind, `DOMAIN` on NETWORK,
and R70–R77. Before the JOURNAL seat of 2026-09-14 (JRN-1):
`3809f24df3232e5d2c1b9a100a60379567e49883d687787af5ac2202eb47b7fc`,
85/85; the widening added A20, R67, R68, R69 and gave A2 its `JOURNAL`.
Before the IDENTITY seat of 2026-09-14 (IDN-1):
`0f8f291470adba76343ceecf6d102e027acf5b33e0737fb09a44542478ddb719`,
81/81; the widening added A19, R64, R65, R66 and gave A2 its
`IDENTITY`. Before the EGRESS seat of 2026-09-14 (EGR-1):
`57f976861774231a86dd0db3f8005ca381d864cdde3cbab87bc31fcbe9e601e8`,
76/76; the widening added A18, R60, R61, R62, R63. Before the BUDGET
seat of 2026-09-13 (BDG-1):
`e65f7b668ee8917b1b3a2d9aa5837f13559ab2935da36b9c63881fdac68c24cf`,
71/71; the widening added A17, R56, R57, R58, R59 and the `cgroup2`
filesystem. Before the HEALTH seat of 2026-09-13 (HLT-1):
`a3ea9fca4c2f118de31b6dd071e7025bc261e7b24f77692cdf5fd519fa8714f7`,
67/67; the widening added A16, R53, R54, R55 and gave A2's two services
their windows. Before the box's worlds became DAEMONS on 2026-09-13 (SRV-1):
`826ab41fea0333d6f347763610e31803a9173c1253ac56cc0709d0aa14545750`,
67/67 then and 67/67 now — the language did not widen; fixture A2 is
`machines/makeen_box.machine` verbatim, and that file's two services
changed from `RESTART never` to `RESTART always` with a `READY` path.
A2 was RE-TAKEN from the file mechanically rather than hand-copied, so
"verbatim" stays a fact. Before the edge boards of 2026-09-12 (PRJ-1):
`f2bf476618d2c5afd9d282f1fe5eba4ce717486b43266b93374e8a53bfc6a40f`,
14 accepts + 50 rejects; the widening added A15, R51, R52, made A3 the
sensor file verbatim with `BOARD pico2`, and re-aimed R34/R35 at the
per-profile board menus. Before USER of 2026-09-12 (USR-1):
`adb8a6e6cc08ce4c5319867128ba9895d0459d06710b39f17b17959a135003ee`,
13 accepts + 45 rejects; the widening added A14, R46-R50 and put
`users` into every accept's counts. Before READY of 2026-09-12 (RDY-1):
`cb031c766d74b95ac2f156447464e97986d1274c965656f8ab0d542cf3414515`,
12 accepts + 42 rejects; the widening added A13, R43, R44, R45.
Before SLOTS of 2026-09-12 (AB-1):
`0994dccb4bdf4b6d2dae8bfb9174c4b4df76ddc753624d30fd4105e19350bf81`,
11 accepts + 40 rejects; the widening added A12, R41, R42 and gave A2
its `SLOTS`. Before the NETWORK kind of 2026-09-12 (NET-1):
`a7f0976ad2bcc757368e7bf86b6850c8b933c4fcbb48b2d8430b01482c5341a8`,
9 accepts + 35 rejects. The widening added A10, A11, R36–R40, put
`networks` into every accept's counts, and made A2 the box file with
its NETWORK and without its `network_up` service. Before the BOARD
clause of 2026-09-12, OS-4:
`0448842222d40d7b8d6b4866c23f42c878eda7c9ea83f6c1717eb3fb7789e9cb`,
8 accepts + 32 rejects. The widening added A9, R33, R34, R35, put the
defaulted board into A1/A3 and made A2 the box file verbatim with
`BOARD rpi4`.)

The machine language's canonical home is THIS repository (like W and
stzu in stz): the fixtures are born here and forked nowhere. Changing
them means re-computing this digest in the SAME commit. A runner cites
the digest it passed against; drift is then a diff, never a surprise.

## Scoreboard

| host | runner | 2026-09-12 |
|---|---|---|
| Zig (`src/machine.zig` + `src/plan.zig`) | `zig build court` / `harb court` | **160/160** — 33 accepts with structural expectations, 127 rejects with expected refusal fragments (132/132 before STATE; 120/120 before FORWARD; 39/40 on the first run of the v0.1 floor, 43/44 on the first run of the BOARD widening, then 51/51 NETWORK, 54/54 SLOTS, 58/58 READY, 64/64 USER, 67/67 the edge boards, 114/114 EGRESS; 116/120 on the first run of the CONSOLE widening, the four refusals accepted by the code as it stood) |

The language's own declaration, `machine.stzu`, judged by stz's
meta-court (`face/stz/Stzu.luau`, run by stz's `stzr`):
**accepted first run** — 7 declarations, 5 forms, 0 expressions,
3 refusals, verbs CAPABILITY MACHINE MOUNT NETWORK PIN SERVICE USER
(5/4/0/3 at the v0.1 floor; NETWORK and USER each added a declaration).

## What conformance means here

- **Accepts prove derivation, not just parsing**: identity (name,
  profile, arch, kernel, libc, console), the counts per kind, the
  service START ORDER as the plan derives it (A5), the GRANTED set
  sorted (A2, A3, A4, A8), and the folded multi-line rationale (A6).
- **Rejects prove the reason, not just the refusal** (exemplar gap G8,
  applied from birth): every reject carries the fragment its refusal
  must contain. R5 (`never a shell line`) is the boot-path law's own
  gate; R17/R18 are "silence is refusal"; R15/R31 are profile
  coherence; R21/R27 the order's guards.
- **The court convicted its own implementation on its first run.** R20
  expected `no declaration grants gpio`; the refusal said `needs gpio,
  which no declaration grants` — same meaning, wrong words, 39/40. The
  implementation's message changed; the fixture did not. A court that
  fails for wording is a court that cannot be satisfied by an
  approximately right runtime.
- **The mechanism was probed before this scoreboard was written**: in
  fresh processes with a deliberately mutated judge — a wrong count
  (A2 services 3 → 99), a wrong fragment (R5), a valid source posing as
  a reject — the court went red three times, each for its named
  reason, and exited nonzero (`experiment/PROTOCOL.md`).

## The boot, judged by the machine itself (JDG-1)

Every image carries `/etc/expected`: the init lines a faithful boot of
the declared machine prints, DERIVED by `harb image` from the plan.
PID 1 records what it says and, when every service is ready, judges
its own ledger against that text in its own words — `judge -- the boot
matches its expectation (/etc/expected, 14 lines)` — and an A/B trial
is committed only on a match. A board the court emulates carries a
second text through the emulator's lens (`/etc/expected.emulator`,
selected by `harb.expect=emulator` on the emulator's boot line and
never on the card's); the diff of the two is the list of the emulator's
lacks, printed at build time. The three pinned transcripts carry the
verdicts: **33, 26 and 84 lines, identical** (26 and 84 since HLT-1,
which gave the box's worlds their health windows; 25 and 81 at SRV-1
when they became daemons; 23 and 75 before that, 22 and 49 before
JDG-1). The box's 84 hold three card boots: the trial through the emulator's lens
committed, the held trial not committed, and the NEGATIVE — the same
trial judged through the board's lens, which the emulator cannot meet:
`differs from its expectation (/etc/expected): 2 line(s) expected and
not said, 2 said and not expected`, the four lines named, `held ...
not committed ... the next boot is A`, and the card read back still
booting A. Each judged line is worded once, in `src/expect.zig`, for
init and for the derivation alike; five unit tests pin the derivation
and the judge's negatives.

## A world's own place, judged by the disk it leaves (OWN-1)

`STATE` on a SERVICE: the directories a world owns, made and handed to
its identity by PID 1 before the world starts. Fixture-first -- A30-A35
accept it and R104-R138 refuse what it must never be: **132/132 to
173/173**, and the pack court 30/30 to 33/33, with the Commons pack's
own READY moved into a directory it owns, because a world that is not
root can no longer signal in root's /run. The first machine that boots
it is `machines/qemu_cloud.machine` with `machines/ringserv.pack`: the
first real server, which ran as root because its signal sat in root's
/run, now runs as `appserver` (2000:2000).

Three things judge it, and none of them is the declaration:

- the machine's own boot line `boot: state -- ringserv owns /run/ringserv
  and /data/ringserv as appserver (2000:2000); each made, then read back
  as that identity's, mode 0700`, said only after the kernel read each
  directory back, and part of the 19 lines the machine judges itself on;
- **the disk the boot leaves behind** (`experiment/os2_image.sh`, from the
  `state.list` that `harb image` derives): `disk: /data/ringserv -- owned
  by 2000:2000, mode 0700` and, beside it, `disk: / -- owned by 0:0, mode
  0755`, read back with `debugfs` from the image after the journal is
  replayed on a copy, and compared with the declaration the image
  derived (a disk that differs says so on its line, whatever the pin
  says) -- the directory is the world's and the disk's root is still the
  machine's;
- **the same image with no disk behind its mount**: the kernel refuses the
  mount, and the machine says `boot: state -- ringserv was not given
  /data/ringserv: the mount it lies on was refused by the kernel; a world
  that owns a directory it was not given does not start`, starts nothing,
  and announces no directory it could not hand over. That boot has no
  verdict, because a world that does not start is never ready: a trial is
  never committed on it, and nothing rolls it back either (RDY-1's safe
  outcome).

The pinned transcripts moved with the seat, in the same commit:
`qemu_cloud_ringserv.expected` **23 to 49 lines** (the state line, the
identity on the start line, the server's own `--data` line, the disk's
three lines and the 21 of the disk-less round) and `cloud_links.expected`
**146 to 148**. Both were read as diffs before they were pinned, and both
were identical on a second boot.

Two probes sit beside it. `experiment/state_probe.sh` runs the act's own
unit tests on Linux -- the directory (made, handed over, read back, no link
followed, every directory above it the machine's) and the signal (a regular
file read without following a link, a stale one cleared) -- and then
against ten mutants, each of which must be convicted by the test named for
it; the two that remove the chown need root, because only a root run hands
a directory to a DIFFERENT owner, and the probe says when it did not run
them. The first run of the first version was red for a real reason, the
standard library calls a chown on a directory opened without `iterate`
unreachable, which in the ReleaseSafe build harb ships in is a panic of
PID 1. `experiment/ringserv_nonroot.sh` measures the server itself,
outside the machine, and judges itself: as uid 2000, from `/`, with an
empty environment, it serves `/health` and keeps its database and the
files beside it in its own directory, and the same probe run with the
server as root must be convicted (four statements fail), or the probe
measures nothing. It is not the machine's image: it looks at the places an
unprivileged user can write on its host, not at all of them.

A third boot judges it from the world's own side (OWN-2).
`machines/qemu_own.machine` runs `harb own` as two identities, each owning
one directory of a disk, with nothing but `harb` on the image: each world
makes a file in its own directory and reads it back, and is refused in the
directory above, in `/` and in the other's directory (a listing and a file).
**53 lines, identical on two runs.** The disk, read back, has each `note`
owned by its identity. Its first boot found that `/` itself was writable by
every identity -- the initial filesystem is a tmpfs, whose root is mode 1777 --
which PID 1 now closes; with that disabled the same boot convicts itself, the
first world exits 1 and the second never starts.

## How many tasks a world may hold (THR-1)

`TASKS n` on a SERVICE becomes cgroup v2's `pids.max`, which counts
processes and threads TOGETHER -- the only number the kernel keeps.
`TASKS 0` is refused (R83), and a count beyond four thousand (R84),
because the number counts tasks and nothing else. **107/107**, from 104.

This is the seat that closed the `threads` seam by dissolving it. The
capability asks WHO ASKED for a thread, which only the runtime knows and
which no seccomp filter can decide; `TASKS` asks HOW MANY the machine
will hold, which only the kernel knows. Each question belongs to
whoever can answer it, and this floor will not enforce `threads`.

`machines/qemu_budget.machine` gained a world sized at six and asking
for twelve:

```
swarm: 5 tasks made, and the kernel refused the next (AGAIN):
    this world is as many as the machine agreed to hold
```

Five children plus the world itself is six. EAGAIN rather than a kill: a
ceiling on how many, not a refusal to be -- and one row below in the
same transcript, BDG-1's greedy world is still killed by signal 9 for
asking for memory it was not granted. Two ceilings, two behaviours, both
the kernel's.

## Which storage is whose (SEE-1)

`SEES` on a SERVICE: which of the machine's declared mounts a world
keeps. `NEEDS [filesystem]` is the grant and this narrows it, which is
why naming a mount without the capability is refused (R78) -- a world
cannot choose sight of storage it never asked to touch. A mount this
machine does not declare (R79), an empty list (R80), one named twice
(R81) and a machine with no MOUNT at all (R82) are refused too.
**104/104**, from 98.

Saying nothing keeps every declared mount, so every machine written
before this clause is unchanged. The FIRST envelope seat that needed a
clause at all: the four before it were derived from `NEEDS`, because
`NEEDS` already knew the answer, and which mounts a world keeps is
information no clause carried.

One check had to move. `MOUNT`s are parsed AFTER `SERVICE`s, so the
service loop cannot ask whether a named mount exists -- the parser has
not read it yet. The capability, empty and duplicate checks happen in
the loop; "is there such a mount" is a second pass once the mounts do
exist, because a refusal must name what the declaration actually holds.

`machines/qemu_confine.machine` grew a second mount to make the choice a
choice, and two worlds that are exact mirrors: `ledger` sees `/data` and
not `/var/log`, `caisse` the other way round. Same machine, same binary,
same capability granted to both, and the only difference between them is
which mount each one named.

## Two machines on one wire (NAM-1)

`DOMAIN` on a NETWORK and the `PEER` kind: the machine becomes its
link's own server of addresses and names. Fixture-first: A21 accepts
the shape, and eight refusals say what a served link is — a peer off
the link (R70), a peer on a link with no domain (R71), two peers on one
address (R72), a peer on the machine's own address (R73), a hardware
address that is a word rather than six pairs (R74), a link this file
never declared (R75), a name the wire cannot carry (R76), and a link
that asks for its own address by dhcp (R77). **98/98**, from 89/89.

The codec is judged beside the code (`src/names.zig`, four tests): a
declared device is answered with the address it was declared and an
undeclared one with silence; an offer carries the resolver, the domain,
an infinite lease and **no router**; the box answers for its peers,
for the short form, case-insensitively, and for itself, and says there
is no such name for anything else; an answer to another question is not
an answer.

And then the thing itself, which nothing else in this repository has
done before: **two machines, booted at the same time, on one wire**
(`experiment/os6_names.sh`, **66 lines**, `machines/names.expected`).
`makeen_names` serves and waits. `caisse_makeen` declares no address,
no resolver and no printer, learns all three from the link, and asks:

```
till: boot: network salle -- eth0 up 192.168.10.40/24 (dhcp),
    dns [192.168.10.1], names on makeen (/etc/resolv.conf)
till: ask imprimante.makeen -- 192.168.10.50 (from 192.168.10.1)
till: ask makeen -- 192.168.10.1 (from 192.168.10.1)
till: ask fantome.makeen -- no such name on this network
    (from 192.168.10.1)
```

The third round is the seat's own negative: the SAME image with a
hardware address nobody declared, which gets nothing at all and is
right to say so.

```
stranger: boot: network salle -- eth0 dhcp:
    no lease after 3 tries (no server answered on this network)
```

The generator agreeing with itself would have proved nothing here; the
box's claim is judged by the device that consumed it, which is the law
PRJ-2 paid for.

## The machine's own record, chained and signed (JRN-1)

`JOURNAL` on a hosted MACHINE: one line per boot, hash-chained and
signed by the device's key, recording what the machine WAS and what it
judged of itself — never what a world did, which is the world's to keep.
Fixture-first: A20 accepts it, R67 refuses a journal on a machine with
no IDENTITY ("an unsigned record is anybody's"), R68 refuses one that
dies with the power, R69 a relative path. **89/89**, from 85/85.

The chain's own logic is judged beside the code (`src/journal.zig`, a
unit test): three entries verify, a single word changed in entry two is
caught with its position and its reason, and a signature from another
device is refused. The claim is the fiscal one, stated exactly:
inalterability is not that a record cannot be changed — any file can —
but that a change cannot go UNNOTICED.

Two machines keep one. `qemu_identity` is booted TWICE on the same disk
(**46 lines**): the first boot finds no record and writes entry 1 after
its verdict; the second reads entry 1 back from inside the machine,
verifies it, prints it, and appends entry 2. `makeen_box` (**121
lines**) carries it across four card boots, and the entry the unmet
trial wrote is the one worth reading: `verdict differed` — the box
writing down that its boot was not the declared one.

## The device's own name, judged across four boots (IDN-1)

`IDENTITY` on a MACHINE: where this device's key lives. PID 1 makes an
Ed25519 pair there the first time the machine boots and loads it every
time after. Fixture-first — A19 accepts it beside a persistent mount,
R64 refuses a relative path, R65 refuses a key on a filesystem that dies
with the power ("a new device every morning"), R66 refuses it on the
edge profile, where custody is the hardware's and the design is
MicroRing's. **85/85**, from 81/81.

`machines/qemu_identity.machine` is the seventh pinned transcript (18
lines): the key is made, `harb attest` signs with it, verifies it, and
then flips one bit in the message and shows the same signature refused --
the half that makes the first half evidence rather than a claim.

**The claim is persistence, so the court boots the same card TWICE.**
`makeen_box.expected` is now 117 lines and holds four card boots: the
trial (the key is CREATED, `KEY1`), **the same card again** (the slot is
`committed, steady` and the key is `already on this device, KEY1`), and
the held and unmet trials on PRISTINE copies, each of which creates its
own (`KEY2`, `KEY3`) -- because a fresh card is a fresh device, which is
exactly what an identity should mean.

The fingerprint is the one thing a declaration cannot know, so it is not
pinned as a value and not normalised to a constant either: each DISTINCT
fingerprint becomes `KEY1`, `KEY2`, … in order of first appearance. Two
builds with two different real keys produce the same pinned text, and a
key that CHANGED between two boots of one card would read as `KEY2` and
convict. Measured: two consecutive builds, real fingerprints
`8038fb3d6c45b2de` and `b6a136f719a92fa3`, one pinned transcript.

## The perimeter, judged by the kernel's own answer (EGR-1)

`EGRESS` on a NETWORK: a list of destinations, or the word `none`.
Fixture-first — A18 accepts a declared reach, R60 refuses `none` beside
a GATEWAY ("a gateway is a way out"), R61 an empty list, R62 a
destination that is not an address and a prefix, R63 `EGRESS` on a
MOUNT by the clause menu. **81/81**, from 76/76.

`machines/qemu_egress.machine` is the machine that proves it, and the
sixth pinned transcript: one destination declared, one not, and two
witnesses that ask the KERNEL rather than the declaration. **19 lines,
identical**:

```
boot: network lan -- eth0 up 10.0.2.15/24
boot: egress lan -- 10.9.0.0/16 and nowhere else:
    no default route
reach 10.9.0.1 -- a route exists: this machine knows a way there
reach 8.8.8.8 -- no route: this machine knows no way there
```

`harb reach <a.b.c.d>` is the witness, as `harb id` is the USER
seat's. A UDP `connect()` is the whole question: it performs the route
lookup and sends nothing, so a machine with no way to an address learns
that without a single packet leaving it.

## The four promises, judged by name (GRT-1)

The hosted profile's four standing promises -- always reachable, a
stable name, a durable log, survives the cut -- are RestoLean's sheet
(Amor's *toujours joignable, nom stable, journal local durable,
traverse la coupure*) made into a verdict. `harb guarantees
<file.machine> <text>` reads the declaration for what is promised and a
text for what is kept, quotes the line that keeps each, and names what
was looked for when one is not. `experiment/judge_guarantees.sh` judges
the box twice and pins both reports in
`machines/makeen_box.guarantees.expected`: **39 lines, identical** --
3 of 4 kept against the board's derived expectation (the fourth needs a
slot decision, which an expectation cannot carry), 1 of 4 against the
emulator's transcript, each of the other three naming a lack of the
emulator. `qemu_hello` promises none of the four and says so. The
mechanism was probed with two mutated texts (the mount line removed,
the wire's line moved after the first start) before this pin was
written.

## The budget, judged by a world the kernel kills (BDG-1)

`MEMORY <mebibytes>` and `CPU <percent of one core>` on a SERVICE, held
by cgroup v2. Fixture-first — A17 accepts both ceilings, R56 refuses a
memory ceiling of zero, R57 a share of zero, R58 more than sixteen
cores' worth, R59 `MEMORY` on a MACHINE (the clause menu). **76/76**,
from 71/71.

`machines/qemu_budget.machine` is the machine that proves it, and it is
the fourth pinned transcript: two worlds on the smallest board, one
inside its ceiling and one over it. `modest` holds 8 MiB of its 64 and
ends, and nothing in the transcript mentions the budget again -- a
ceiling that holds is a ceiling nobody hears about. `greedy` asks for
far more than its 32 MiB and is **killed by signal 9, five times**,
inside its own group: its neighbour never felt it, PID 1 applied the
declared RESTART policy, gave up after five, and the box carried on to
a clean halt. **35 lines, identical.** The machine never reaches a
verdict on its own boot, and that is the truth about a boot in which a
world never served: `greedy` declares the signal it would give if it
were serving, and never gives it.

## The health window, judged by a world that stops serving (HLT-1)

`HEALTH <seconds>` on a service that declares READY: the window within
which the daemon must refresh that path. Fixture-first — A16 accepts a
declared window; R53 refuses HEALTH without READY ("HEALTH is measured
on the READY path"), R54 refuses a window of zero, R55 refuses HEALTH on
a MOUNT by the clause menu. **71/71**, from 67/67, and the court was red
for three named reasons before the parser was touched.

What the seat governs, and what judges it: PID 1 feeds the hardware
watchdog only while every world with a window is fresh, and a trial
commits only once every such world has been ready THROUGH one full
window. Staleness latches. The POSITIVE is pinned in the box's
transcripts (`health -- kds every 5s, poste every 5s`, and a commit line
that says the window was held); the NEGATIVE is demonstrated in the WSL
rehearsal, where `signals` is a `flock` that creates its path once and
never touches it again — caught in seconds, with no kernel and no
emulator. The window's own logic is judged beside the code in
`src/init.zig` (ready at the signal, proven one window later, the latch,
and a world with no window owing nothing).

## The edge projection, judged as text (PRJ-1)

`machines/cold_room_sensor.machine` (fixture A3 verbatim, `BOARD
pico2`) → `harb project` → a real MicroRing project: a folder with a
`device.ring` whose `Device([...])` carries the board and both pins.
Diffed against `machines/cold_room_sensor.device.ring.expected` by
`experiment/judge_project.sh`: **20 lines, identical** — and then run
through MicroRing itself, which prints `pico2 . 2 pin(s) . 2000ms` and
`done`. The consumer is part of the judge since PRJ-2, when the first
projection passed the diff and was REFUSED by MicroRing: its comments
were written with the machine language's `--` where Ring's is `#`, so
Ring read the prose as code and an apostrophe opened a string literal.
A diff against our own generator could never have found that. Its other
negatives are the two refusals: projecting a hosted machine, and
imaging an edge one. What does not cross over is printed rather than dropped — the
flash mount (the substrate's), the capabilities (the machine's
envelope), each service's behaviour (the Device language's).

## The identity, judged from inside the machine (USR-1)

`machines/qemu_hello.machine` declares `USER world` and runs its
witness service as it. The pinned transcript carries both halves: PID 1
saying `start whoami -- pid N -- /harb id -- as world (1000:1000)`,
and the service's own answer from inside the machine, `id: uid=1000
gid=1000`. The image derives `/etc/passwd` and `/etc/group` from the
declared identities and root, so a world that asks a name service gets
the same answer the declaration gave. **32 lines, identical**; the pin
moved from 28 in the same commit as the seat.

## The slots, judged by the card itself (AB-1)

`machines/makeen_box.machine` declares `SLOTS "/dev/mmcblk0p1"`. The
court boots the card as a trial of slot B (`harb.slot=B` on the
emulator's line, `harb.watchdog=off` because the emulator resets on
arming) and the pinned transcript carries three witnesses: PID 1's own
lines (`a trial (committed is A)` … `committed: every service is
ready; config.txt now boots B`), the card's `config.txt` read back after the
boot (`os_prefix=slots/B/` first), and a second boot of a PRISTINE copy
of the card with the trial held — not committed, restarted — whose
card still says `os_prefix=slots/A/`. **49 lines, identical.** The
hardware watchdog's answer is the board's to give.

## The network, judged by a lease (NET-1)

`machines/makeen_qemu.machine` declares `NETWORK lan` with `ADDRESS
dhcp`; the image gives the `virt` machine a virtio NIC on QEMU's
user-mode network, whose built-in server is the oracle. The pinned
transcript carries the lease: `network lan -- eth0 up 10.0.2.15/24,
gateway 10.0.2.2 (dhcp), dns [10.0.2.3]` — **22 lines, identical**.
`makeen_box.expected` was re-pinned at 21 lines: its static NETWORK is
refused NODEV under `raspi4b` (no Ethernet there) and the two worlds
now run, since a network is brought up like a mount and a refused one
does not hold services back. Both re-pins travel with the NETWORK kind
in one commit.

## The board's image, judged by the same board emulated (OS-4)

`machines/makeen_box.machine` (BOARD rpi4) → `experiment/os2_image.sh
makeen_box` → the arm64 kernel for BCM2711, the card's tree, the
emulator's tree, a 256 MiB SD image → QEMU `raspi4b` → the transcript
against `machines/makeen_box.expected`: **17 lines, identical**
(2026-09-12). The pin is the EMULATOR's truth and says so in its lines:
`ext4 at /data -- done` on `/dev/mmcblk0p2` by its declared name, and
`net: eth0 -- no such interface (NODEV)` with the two worlds `never
started` — the emulator has no Ethernet. The board's first boot is
judged against this pin and is expected to differ there and nowhere
else.

## The Makeen box, judged by its boot transcript (OS-3)

`machines/makeen_qemu.machine` (aarch64, `virt`, a virtio ext4 disk at
`/data`) → `experiment/os2_image.sh makeen_qemu` → Linux 6.12.109 for
arm64 → QEMU → the serial transcript, normalised and diffed against
`machines/makeen_qemu.expected`: **20 lines, identical** (2026-09-12).
The expectation was pinned from the first deterministic boot under the
AFTER-readiness rule. `qemu_hello.expected` was re-pinned in the same
commit as that rule (28 lines): `hello` now starts after `self` exits,
where before the two exits interleaved and the judge convicted the
flake on the third boot (`experiment/PROTOCOL.md`, OS-3 finding 3).

## The image, judged by its boot transcript (OS-2)

`machines/qemu_hello.machine` → `experiment/os2_image.sh` → Linux
6.12.109 (pin in `vendor/PIN.md`) + initramfs → QEMU → the serial
transcript, normalised (firmware banner, CRs, pids) and diffed against
`machines/qemu_hello.expected`: **28 lines, identical** (2026-09-12).
The expectation was pinned from the first boot — there was no earlier
oracle for a machine that had never booted — and every later boot is
judged against it; a change to the expectation travels in the same
commit as the change that caused it.

## The init, judged by its transcript under WSL (OS-1)

`machines/wsl_rehearsal.machine` under WSL Ubuntu, x86_64 static
binary, transcripts in `zig-out/wsl/` (never committed — rendered from
the run):

- rehearsal from an ordinary pid (`--rehearse --turns 8`): mounts
  narrated and not executed; `once` exits 0, stays down; `flaky` exits
  1, restarted 5 times, given up on; `steady` exits 0, restarted;
- PID 1 inside `unshare -Urpf --mount-proc`: pid 1, children 2–10,
  `proc` mounted, `sysfs` and `devtmpfs` refused by the kernel with
  `PERM`, the same reaper behaviour, `init would now halt the machine`.
- since RDY-1, both sides of READY: `signals -- ready
  (/tmp/harb-signals.ready)` and then `start after_signals`, against
  `after_mute has not started -- what it comes AFTER has not signalled
  ready`. The script removes the signal paths before each run; a stale
  signal would make a daemon ready before it ever started.
