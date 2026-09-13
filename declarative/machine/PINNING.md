# machine v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
57f976861774231a86dd0db3f8005ca381d864cdde3cbab87bc31fcbe9e601e8
```

(Before the BUDGET seat of 2026-09-13 (BDG-1):
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
| Zig (`src/machine.zig` + `src/plan.zig`) | `zig build court` / `stzos court` | **76/76** — 15 accepts with structural expectations, 52 rejects with expected refusal fragments (39/40 on the first run of the v0.1 floor, 43/44 on the first run of the BOARD widening, then 51/51 NETWORK, 54/54 SLOTS, 58/58 READY, 64/64 USER, 67/67 the edge boards) |

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
the declared machine prints, DERIVED by `stzos image` from the plan.
PID 1 records what it says and, when every service is ready, judges
its own ledger against that text in its own words — `judge -- the boot
matches its expectation (/etc/expected, 14 lines)` — and an A/B trial
is committed only on a match. A board the court emulates carries a
second text through the emulator's lens (`/etc/expected.emulator`,
selected by `stzos.expect=emulator` on the emulator's boot line and
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

## The four promises, judged by name (GRT-1)

The hosted profile's four standing promises -- always reachable, a
stable name, a durable log, survives the cut -- are RestoLean's sheet
(Amor's *toujours joignable, nom stable, journal local durable,
traverse la coupure*) made into a verdict. `stzos guarantees
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
pico2`) → `stzos project` → a real MicroRing project: a folder with a
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
saying `start whoami -- pid N -- /stzos id -- as world (1000:1000)`,
and the service's own answer from inside the machine, `id: uid=1000
gid=1000`. The image derives `/etc/passwd` and `/etc/group` from the
declared identities and root, so a world that asks a name service gets
the same answer the declaration gave. **32 lines, identical**; the pin
moved from 28 in the same commit as the seat.

## The slots, judged by the card itself (AB-1)

`machines/makeen_box.machine` declares `SLOTS "/dev/mmcblk0p1"`. The
court boots the card as a trial of slot B (`stzos.slot=B` on the
emulator's line, `stzos.watchdog=off` because the emulator resets on
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
  (/tmp/stzos-signals.ready)` and then `start after_signals`, against
  `after_mute has not started -- what it comes AFTER has not signalled
  ready`. The script removes the signal paths before each run; a stale
  signal would make a daemon ready before it ever started.
