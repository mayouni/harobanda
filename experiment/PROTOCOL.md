# JDG-1 — the machine judges its own boot: the expectation rides in the image, a trial commits only on a match

The author said: close the loop. The loop was this: every boot was
judged from OUTSIDE — QEMU's serial transcript, normalised and diffed
by a script against `machines/<name>.expected` — while the machine
itself committed an A/B trial on "every service is ready" and nothing
else. The Makeen box's emulated trial committed with its network
refused NODEV, and the court was green, because the court judged the
transcript and the machine judged nothing.

## What closes it

`stzos image` now DERIVES the init lines a faithful boot prints — from
the plan, through a LENS — and the initramfs carries them as
`/etc/expected`. PID 1 records every judged line it says (a ledger:
written first, then echoed to the console, so the two cannot disagree)
and, the moment every service is ready, judges the ledger against the
expectation in its own words:

```
boot: judge -- the boot matches its expectation (/etc/expected.emulator, 16 lines)
boot: slot B -- committed: every service is ready and the boot matches its expectation; config.txt now boots B, A is the fallback
```

The rule for a trial changed from "ready" to "ready AND matches". A
boot that differs names the lines and holds itself:

```
boot: judge -- the boot differs from its expectation (/etc/expected): 2 line(s) expected and not said, 2 said and not expected
boot: judge -- expected, not said: network lan -- eth0 up 192.168.10.1/24
boot: judge -- expected, not said: watchdog armed (/dev/watchdog)
boot: judge -- said, not expected: network lan -- eth0: no such interface (NODEV)
boot: judge -- said, not expected: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
boot: slot B -- held: every service is ready but the boot is not the one expected; not committed, the watchdog is no longer fed -- the next boot is A
```

No expectation is no verdict, and nothing to judge by is nothing to
commit on: text before act, applied to the act itself.

## The lens

The emulator lacks what the board has — no GENET, and a watchdog it
resets on — so one expectation cannot be true of both. The image
derives two: `/etc/expected` (the board's) and `/etc/expected.emulator`
(the emulator's), from one plan and a `Lens` with one field per lack.
The emulator's boot line says `stzos.expect=emulator`, beside the
`stzos.watchdog=off` it already said; the card's `cmdline.txt` never
does. **The diff of the two texts IS the list of the emulator's lacks**,
printed at build time:

```
--- the emulator's lacks (expected vs expected.emulator):
  the board:  boot: network lan -- eth0 up 192.168.10.1/24
  the board:  boot: watchdog armed (/dev/watchdog)
  the emulator:  boot: network lan -- eth0: no such interface (NODEV)
  the emulator:  boot: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
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

# JDG-1 — the machine judges its own boot: the expectation rides in the image, a trial commits only on a match

The author said: close the loop. The loop was this: every boot was
judged from OUTSIDE — QEMU's serial transcript, normalised and diffed
by a script against `machines/<name>.expected` — while the machine
itself committed an A/B trial on "every service is ready" and nothing
else. The Makeen box's emulated trial committed with its network
refused NODEV, and the court was green, because the court judged the
transcript and the machine judged nothing.

## What closes it

`stzos image` now DERIVES the init lines a faithful boot prints — from
the plan, through a LENS — and the initramfs carries them as
`/etc/expected`. PID 1 records every judged line it says (a ledger:
written first, then echoed to the console, so the two cannot disagree)
and, the moment every service is ready, judges the ledger against the
expectation in its own words:

```
boot: judge -- the boot matches its expectation (/etc/expected.emulator, 16 lines)
boot: slot B -- committed: every service is ready and the boot matches its expectation; config.txt now boots B, A is the fallback
```

The rule for a trial changed from "ready" to "ready AND matches". A
boot that differs names the lines and holds itself:

```
boot: judge -- the boot differs from its expectation (/etc/expected): 2 line(s) expected and not said, 2 said and not expected
boot: judge -- expected, not said: network lan -- eth0 up 192.168.10.1/24
boot: judge -- expected, not said: watchdog armed (/dev/watchdog)
boot: judge -- said, not expected: network lan -- eth0: no such interface (NODEV)
boot: judge -- said, not expected: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
boot: slot B -- held: every service is ready but the boot is not the one expected; not committed, the watchdog is no longer fed -- the next boot is A
```

No expectation is no verdict, and nothing to judge by is nothing to
commit on: text before act, applied to the act itself.

## The lens

The emulator lacks what the board has — no GENET, and a watchdog it
resets on — so one expectation cannot be true of both. The image
derives two: `/etc/expected` (the board's) and `/etc/expected.emulator`
(the emulator's), from one plan and a `Lens` with one field per lack.
The emulator's boot line says `stzos.expect=emulator`, beside the
`stzos.watchdog=off` it already said; the card's `cmdline.txt` never
does. **The diff of the two texts IS the list of the emulator's lacks**,
printed at build time:

```
--- the emulator's lacks (expected vs expected.emulator):
  the board:  boot: network lan -- eth0 up 192.168.10.1/24
  the board:  boot: watchdog armed (/dev/watchdog)
  the emulator:  boot: network lan -- eth0: no such interface (NODEV)
  the emulator:  boot: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
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
language, the firmware and the tiers are its own. `stzos project`
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
- **`stzos project <file.machine> --out <dir>`** (`src/project.zig`):
  the `device.ring`, and a printed account of what did NOT cross over —
  the flash MOUNT (the substrate mounts it), the capabilities (the
  machine's envelope, which MicroRing has no gate for), each service's
  behaviour (the Device language's). The generated file carries the
  same account in its own comments, so it is legible where it lands.
- **Both refusals**: `stzos project` refuses a hosted machine, and
  `stzos image` refuses an edge one, each naming the other verb.

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
- **`stzos id`**, the witness: a machine has no coreutils, so the one
  binary answers `uid=N gid=N` from inside it.

## What was measured

`machines/qemu_hello.machine` declares `USER world` and a service that
runs `stzos id` as it. The boot says both halves: `start whoami -- pid
N -- /stzos id -- as world (1000:1000)` from PID 1, and `id: uid=1000
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

A Linux zig is needed: the Windows one cross-compiles stzos but cannot
drive `make` inside WSL. It is fetched ONCE and **pinned by digest**
(`experiment/zigcc_fetch.sh`, `vendor/zig/PIN.txt`, sha256 from
ziglang.org's own index), exactly as the kernel tarball and the board
firmware are. The experiment lives behind `STZOS_CC=zigcc` on
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
`zigcc_kernel.sh`, the six probes, and `STZOS_CC=zigcc` in the image
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
  (/tmp/stzos-signals.ready)` followed by `start after_signals`, and
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
  `cmdline.txt` carrying `stzos.slot=A|B`; `config.txt` names the
  committed slot in `os_prefix` and, under the firmware's own
  `[tryboot]` filter, the other. The same image fills both slots at
  first.
- **PID 1's slot logic** (`src/init.zig`): after the mounts it reads
  which slot booted (`stzos.slot=` on `/proc/cmdline`), mounts the
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
- **`stzos update <dir>`** (`src/update.zig`): the file half — read the
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
- `stzos update` on a fake boot partition: slot B written (four
  files), `config.txt` untouched; with `cmdline.txt` removed, refused
  whole.

## What was found

1. **QEMU's raspi4b resets the board the moment the watchdog is
   armed.** Its power-management model has no countdown and reads the
   driver's "full reset on expiry" bit as "reset now"; the first trial
   boot vanished after the capability lines with its buffered output,
   and the card was unchanged. The emulator's boot line now carries
   `stzos.watchdog=off` (never the card's `cmdline.txt`), PID 1 states
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
- **`stzos net`** by hand does the same: `<iface> <cidr> [gateway]` or
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
- **`stzos net <iface> <a.b.c.d>/<n>`** (`src/net.zig`): a role of the one
  binary — four ioctls on a datagram socket, every result stated, no
  DHCP, no gateway, no DNS. The box's `network_up` service is now a
  program that exists: `RUN ["/stzos", "net", "eth0", "192.168.10.1/24"]`.
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
  declared name; `gpio` refused as declared; `network_up` ran `stzos
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
  `make CC="zig cc"`; the judge into `stzos judge`.

---

# OS-3 — the Makeen box: the aarch64 image, a persistent partition, and AFTER made deterministic

Ordered by the author on 2026-09-12 ("take decision on my behalf on the
waiting rows, and then go for OS-3, the aarch64 image for the Makeen
box"). The three rulings are in `doc/PROVENANCE.md` ("The rulings of
2026-09-12"); the mailbox is `softanza/mailbox/stzos.md`.

## What was built

- **`stzos image` for aarch64**: one `Target` table per architecture
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
- The judge into `stzos judge`; one virtio disk per image today.

---

# OS-2 — the machine boots: a vendored kernel, an image derived from the plan, QEMU, the transcript judged

Ordered by the author on 2026-09-12 ("install qemu, gcc and make in WSL
and go for OS-2"), the same day as OS-1.

## What was built

- **`stzos image`** (`src/image.zig`): from a judged plan, three texts
  and no toolchain — `initramfs.list` in the kernel's own gen_init_cpio
  format (device nodes for PID 1, the mount points, `/stzos`, every
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
- Image: initramfs 4,232,704 bytes — stzos 3.4 MB unstripped, stzr
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
- The judge lives in a shell script today; folding it into `stzos
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
