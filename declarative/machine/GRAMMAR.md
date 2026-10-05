# machine — the machine declaration language, v0.1

A `.machine` file declares a machine whole: its profile, the
capabilities it grants and refuses, its mounts, its pins, and the
services it keeps alive. It declares; it does not compute. From a judged
declaration the boot plan is DERIVED (`harb plan`), and on a hosted
machine the same binary executes that plan as PID 1 (`harb init`).
This document is the normative text; `fixtures.json` beside it is the
judge (pin in `PINNING.md`); `machine.stzu` beside it is this language
declared in stzu, judged by stz's meta-court.

This v0.1 is the CONFORMANCE FLOOR: exactly rich enough to declare the
three profiles a machine can have — a hosted box (A2), an edge sensor
(A3), a touch phone (A4) — and to boot the first of them. Widening the
floor means adding fixtures first, prose second (the W discipline).

## Provenance (each decision has a source)

- **The Grammar Commons** (`ringua/docs/commons.md`, C6) adopted whole,
  as stzu did: `--` comments, double-quoted strings that may span lines
  with continuation whitespace folding to one space (A6), lower_snake
  identifiers, UPPER_SNAKE keywords, the mixed-case word refused at the
  tokenizer (R14), trailing commas (A8), CRLF never diagnosed (A7),
  RATIONALE mandatory on every declaration (R4).
- **stzu / ZML**: the declaration shape `DEFINE <KIND> <name> AS ( … )`
  verbatim, so a `.machine` file elevates to ZML by the same table stzu
  carries.
- **stzlib's System Foundation**
  (`stzlib/…/base/doc/design/SOFTANZA_SYSTEM_FOUNDATION.md`): the
  capability vocabulary is `stzSystemCapabilities`' nine names on its
  four-kind lattice, unchanged; "silence is refusal" is `stzSystemScope`'s
  down-constrain law (a target that does not grant, refuses).
- **ZinOS** (`zin/doc/vision/ZIN_OS_VISION_v1_0.md`): the two profiles
  Edge and Touch, kept, plus the hosted profile this repository adds
  (the Omarchy lesson: the first machine to own is a declared system
  over a vendored Linux, not a kernel).
- **The exemplar study's gaps** answered in the grammar: identity
  structural (G4: PROFILE/ARCH/KERNEL required), refusal phrasing as
  declared data (G3: `machine.stzu`'s REFUSAL declarations), reference
  resolution at check time (G6: AFTER and NEEDS), rejects carrying
  their expected fragment (G8).

## Lexical form (Commons C6)

- Comments: `--` to end of line. No block comment.
- Strings: double quotes only; may span lines; no escapes in v0.1.
- Numbers: unsigned decimal digits (PIN's GPIO seat is the one carrier).
- Identifiers: `[a-z_][a-z0-9_]*`, case-sensitive. Keywords and clause
  names: UPPER_SNAKE, reserved. A word that is neither is refused.
- Lists: `[a, b, c]` of words, or `["a", "b"]` of strings, trailing
  comma allowed, never mixed. `[]` is legal in either seat.
- Encoding UTF-8; LF and CRLF both accepted.

## Grammar (EBNF)

```
file        = declaration { declaration } ;
declaration = "DEFINE" kind IDENT "AS"
              "(" [ clauses ] ")" rationale ;
kind        = "MACHINE" | "SERVICE" | "CAPABILITY"
            | "MOUNT" | "PIN" | "NETWORK" | "USER" | "PEER" ;
rationale   = "RATIONALE" STRING ;         (mandatory)

clauses     = clause { "," clause } [ "," ] ;
clause      = CLAUSE_NAME value ;
value       = STRING | IDENT | NUMBER
            | name_list | string_list ;
name_list   = "[" [ IDENT  { "," IDENT  } [ "," ] ] "]" ;
string_list = "[" [ STRING { "," STRING } [ "," ] ] "]" ;
```

The value shape of every clause is fixed by its name (tables below); a
clause outside its kind's table is refused naming the allowed set
(R12); a clause given twice is refused (R30). `DEFINE` is the one verb
(R1, R3).

## The kinds

`FLEET`, `MEMBER`, `RETIREMENT` and `ROUTE` are kinds of this same
language and are refused in a machine file by name (R85-R87, R102): a
machine declares what ONE machine is, and no machine can say who else
is in its estate, which keys it has held, or which links are joined.
They are the fleet grammar's, `declarative/fleet/GRAMMAR.md` (FLT-1,
RET-1, FWD-1). Which file a kind belongs
in is one EXHAUSTIVE switch, `belongsToFleet`, asked by both parsers --
never a condition that names the kinds, which is how a new one walks
past it: with the old `.FLEET or .MEMBER`, a machine file carrying a
RETIREMENT was not refused for a wrong reason, it was ACCEPTED.


### DEFINE MACHINE — exactly one, and first (R9, R10)

| clause | value | obligation |
|---|---|---|
| `PROFILE` | `hosted` \| `edge` \| `touch` | required |
| `ARCH` | `x86_64` \| `aarch64` \| `riscv32` \| `riscv64` \| `thumbv7em` | required (R11) |
| `KERNEL` | `linux` \| `none` \| `android` | required; must agree with the profile (R15) |
| `LIBC` | `musl` \| `none` \| `bionic` | optional; defaults by profile; a contradiction is refused (R31) |
| `BOARD` | hosted: `qemu_pc` \| `qemu_virt` \| `rpi4`; edge: `sim` \| `pico2` \| `pico2w` \| `esp32c6` | optional; each profile has its own menu and its own emulator board, and a board of the other profile is refused by name (R35, R51). A touch machine's device is the phone and declares none. Defaults: hosted by ARCH (`x86_64` → `qemu_pc`, else `qemu_virt`), edge → `sim` (A15). A board of another architecture is refused (R33, R52); an unknown board is refused (R34) |
| `IDENTITY` | string | optional, hosted only — the absolute path where this device's own key lives. PID 1 makes an Ed25519 pair there the first time the machine boots and loads it every time after. It must sit inside a declared PERSISTENT mount (R65), be absolute (R64), and the edge profile is refused it (R66): an edge device's key is MicroRing's, and its custody is the hardware's |
| `JOURNAL` | string | optional, hosted only — where this machine keeps its OWN record: one line per boot, hash-chained and signed by the device's key. Needs an `IDENTITY` to sign with (R67), must be absolute (R69) and must live on a declared persistent mount (R68). It records what the machine was and what it judged of itself, never what a world did |
| `FORWARD` | the word `yes` | optional, hosted only (R95) — this machine is the way from one of its networks to another: the kernel's own forwarding (`/proc/sys/net/ipv4/ip_forward`), switched on once every network is up and READ BACK before the boot says so. It forwards among **all** its networks and filters nothing, because the kernel decides by the interface a packet ARRIVES on and a list of networks here would name a perimeter nothing keeps. Saying nothing is not being the way: a machine on two links that does not say it never was. The word is `yes` (R96, R97), and a machine with fewer than two networks has nothing to forward between (R98, R99; a loopback is a network a machine declares and is not a way to anywhere, so it is not counted, R100). A machine that forwards is a way off every link it joins, so it cannot say `EGRESS none` for one of them (R101). Which links such a machine may join is a fact about a SET, and the fleet declares it (`ROUTE`, `declarative/fleet/GRAMMAR.md`); the boot line is `boot: forward -- between lan and core: ...`. The servers of the links it serves start AFTER that line, and offer the router and answer for the far links only if the switch read back as on: a promise about the way is made once the kernel has said there is one |
| `SLOTS` | string, the boot partition's device (`"/dev/mmcblk0p1"`) | optional — the machine updates A/B: two slots on that partition, `config.txt` naming the committed one and, under `[tryboot]`, the other; PID 1 reads which slot it booted (`harb.slot=` on the cmdline), arms the watchdog, and commits a trial only once every service has started. Needs a board whose firmware can try a slot (`rpi4`; R41); an absolute device path (R42) |
| `CONSOLE` | string, a device | optional; defaults `/dev/console`, `uart0`, `logcat` by profile. **Hosted: a port the board HAS** (R91-R94) -- `qemu_pc` `/dev/ttyS0`..`/dev/ttyS3`, `qemu_virt` `/dev/ttyAMA0`, `rpi4` `/dev/ttyS1` (the mini-UART on the header pins; its PL011 goes to Bluetooth) -- or nothing, which is the kernel's own `/dev/console` and on the board is its first port (A25, A26). The kernel's boot line follows it: the card's `cmdline.txt` and the emulator's line both name the port, and the emulator listens on that port and no other. PID 1 then asks the kernel which device its console really is (`TIOCGDEV`) and says the declared line only when they agree; otherwise it says both, and the boot differs from its file (CON-1). Edge and touch: the substrate's; this repository neither boots nor narrates them, and does not check them |

The BOARD names what the machine is built for. An edge machine's board
is MicroRing's vocabulary verbatim (`sim` is its simulator, `pico2` and
`pico2w` its tier-2 flagship, `esp32c6` its tier 3), because an edge
machine is PROJECTED onto that substrate and never imaged here:
`harb project` writes the `device.ring` a MicroRing project is, and
refuses a hosted machine; `harb image` refuses an edge one.

For a hosted machine the BOARD is what the image is built for: the
emulator court's machines (`qemu_pc` on x86_64, `qemu_virt` on aarch64)
or a real board.
`rpi4` is the Raspberry Pi 4 Model B — the commodity board chosen on
2026-09-12 for the Makeen box (`doc/PROVENANCE.md`): mainline kernel
support, an SD card, Ethernet, QEMU emulation of the same board so the
image is judged before the hardware is. Widening the menu is a
fixture-first act (A9, R33, R34 are the board's own).

The profile fixes the substrate: **hosted** runs on KERNEL linux with
LIBC musl (a vendored kernel, a static image, this binary as PID 1);
**edge** runs on KERNEL none with LIBC none (the binary is the device);
**touch** runs on KERNEL android with LIBC bionic (Android's kernel and
init; the launcher is the pack).

### DEFINE SERVICE — a process the machine keeps

| clause | value | obligation |
|---|---|---|
| `RUN` | string list, one word of the argv per string | required, non-empty (R28); a string is refused (R6) |
| `RESTART` | `never` \| `always` \| `on_failure` | optional, default `never` (R25) |
| `AFTER` | name list of services | optional; each resolves (R8), never itself (R27), never a cycle (R21) |
| `NEEDS` | name list of capabilities | optional; each must be declared AND granted (R17, R18) |
| `READY` | string | optional, daemons only — the absolute path the service creates when it is serving (R43, R44, R45); see the readiness rule below |
| `HEALTH` | number (seconds) | optional — the window within which the daemon must REFRESH its READY path. Requires READY (R53); 0 is refused (R54), and so is a window longer than an hour. See the health rule below |
| `MEMORY` | number (mebibytes) | optional — the ceiling the KERNEL holds this world to. 0 is refused (R56), and so is a number big enough to be bytes by mistake. See the budget rule below |
| `CPU` | number (percent of ONE core) | optional — 50 is half a core, 200 is two of them. 0 is refused (R57), and so is more than sixteen cores' worth (R58) |
| `TASKS` | number | optional — how many TASKS the machine will hold for this world: cgroup v2's `pids.max`, which counts processes and threads TOGETHER because that is the only number the kernel keeps. A fork or a thread past it gets EAGAIN; the world is not killed. `TASKS 0` is refused (R83) and so is a count beyond four thousand (R84). The runtime's own housekeeping threads count against it, which is right: the machine is sizing the world |
| `SEES` | name list | optional — WHICH of the machine's declared mounts this world keeps sight of. `NEEDS [filesystem]` is the grant and this narrows it, so it is refused without that capability (R78); a mount this machine does not declare (R79), an empty list (R80), one named twice (R81), and a machine with no MOUNT at all (R82) are refused. Saying nothing keeps every declared mount, which is what every machine written before this clause did |
| `USER` | name | optional — a declared USER this service runs as; PID 1 drops to that uid and gid between fork and exec. A name that resolves to nothing is refused at check time (R46). Saying nothing is how a service runs as the machine itself |

### DEFINE USER — a declared identity

| clause | value | obligation |
|---|---|---|
| `UID` | number | required — 1..65534; **0 is refused** (R47), and uniqueness is enforced (R48) |
| `GID` | number | optional — defaults to the UID; 0 refused, range enforced (R50) |

Hosted machines only (R49): an edge machine runs one program and has no
identities to hand out, and a touch machine's identities are Android's.
A machine has no `/etc/passwd` until it declares one; then the image
derives `passwd` and `group` from exactly the declared set plus root,
with `/nonexistent` as every shell, because there is none. **Root is
what a service gets by saying nothing** — there is no way to declare a
root identity, so a service that needs the machine's own powers is
visibly the one with no USER line.

### DEFINE NETWORK — one interface, one way to an address

| clause | value | obligation |
|---|---|---|
| `INTERFACE` | string | required — the interface's name (`"eth0"`); one network per interface (R39) |
| `ADDRESS` | `dhcp` \| string `"a.b.c.d/n"` | required — a leased address, or a static address with its prefix; an address without its prefix is refused (R38) |
| `GATEWAY` | string `"a.b.c.d"` | optional, static only — a dhcp network learns its gateway (R37); not an address is refused (R40) |
| `EGRESS` | string list of destinations, or the word `none` | optional — how far this network REACHES. A list writes one route per destination and NO default route; `none` writes no route at all. Saying nothing is today's behaviour: a declared GATEWAY becomes a default route. `none` with a GATEWAY is refused (R60), an empty list is refused (R61), a destination is an address and a prefix, never a name (R62), and a list whose destinations together cover EVERY address is refused however it is spelled -- `0.0.0.0/0`, `10.0.0.0/0`, or `0.0.0.0/1` with `128.0.0.0/1` -- because everywhere already has a spelling: no EGRESS at all (R88-R90, STZ-OS-RULING-06); half the space is still a perimeter (A24). The rule's story is EGR-1 to EGR-3 in `experiment/PROTOCOL.md` |
| `DNS` | string list | optional, static only — the servers; a dhcp network learns them |
| `DOMAIN` | string | optional, static only — the name this link answers to, which makes this machine the link's own SERVER of addresses and names (`"makeen"`). A dhcp link is refused (R77): a machine that asks for its own address is not the one that hands them out. A domain is lowercase labels, digits and the hyphen, separated by dots. One machine answers for a domain once (R103): two links under one name would make a name on either a name on both, and a machine that is the way between them could never be asked for the far one by its full name |

A NETWORK needs the `network` capability granted (R36: silence is
refusal, as for a service). A NETWORK is to the wire what a MOUNT is to
the disk: PID 1 brings every declared network up **before any service
runs**, in declaration order, and states the result — the address it
carries, the gateway it set, the lease it was given, or the refusal by
name. A dhcp network is served by a client in the one binary
(`src/netcfg.zig`: DISCOVER, OFFER, REQUEST, ACK, three tries); the
emulator court judges it against QEMU's user-mode network, whose
server leases `10.0.2.15` with router `10.0.2.2` and dns `10.0.2.3`.
Named seams: lease renewal, a DNS resolver, the box as a DHCP SERVER
for the phones, IPv6.

**AFTER waits for readiness, and the RESTART policy says what ready
means.** A service with `RESTART never` is a one-shot: it is ready when
it has exited 0, and if it exits otherwise, whatever comes AFTER it
never starts (init says so by name). A service with `RESTART always` or
`on_failure` is a daemon: it is ready as soon as it has been spawned —
**unless it declares `READY "<path>"`**, and then it is ready when it
CREATES that path: its own word that it is serving, rather than the
kernel's word that it was started. A daemon that never signals never
becomes ready; its dependents never start and are named at the end,
and an A/B trial never commits. There is no timer, by design: a timer
would race a boot, and a box that refuses to commit an update whose
world never came up is behaving correctly. READY is refused on a
one-shot (R43), must be absolute (R44), and one path signals for one
service (R45).

**A BUDGET is a ceiling the kernel holds, not a promise the world
keeps.** `MEMORY <mebibytes>` and `CPU <percent of one core>` are
written into a cgroup v2 group per world — a group is a directory, a
ceiling is a line of text in it — and the two behave differently on
purpose. Memory KILLS: a world that allocates past its ceiling is
SIGKILLed inside its own group, its neighbours never feel it, and PID 1
reaps it and applies the declared RESTART policy like any other death.
CPU THROTTLES: a world that wants more time waits for its next slice,
and nothing dies, so a held cpu ceiling appears in no transcript at
all. A machine that declares no budget mounts no cgroup filesystem and
asks its kernel for no controller: the plumbing a declaration did not
ask for is not built (BDG-1). `MEMORY` and `CPU` are a SERVICE's, never
a MACHINE's (R59) -- the machine's own total is the board's.

**HEALTH is that word, repeated.** A world can be alive and wedged: the
process is there, the kernel is content, and nothing is served. `HEALTH
<seconds>` is the window within which the daemon must REFRESH its READY
path, and it changes two things. PID 1 feeds the hardware watchdog only
while every world with a window is fresh — the first that goes stale is
named, the feed stops, and the board's reset into the committed slot is
the answer. The watchdog is PID 1's alone: it opens the device
close-on-exec before it spawns the first world, so no world inherits it
and none can keep the box fed or disarm it (WDG-1). And an A/B trial commits only once every such world has
been ready THROUGH one full window: "serving" measured at the instant
of the signal is not worth an update, "serving one window later" is.
Staleness LATCHES: a world that recovers does not resume the feed,
because a feed that resumed would hide exactly the fault the watchdog
exists for. HEALTH is measured on the READY path, so a service without
one is refused it (R53); a window of zero (R54) and a window longer
than an hour are refused as promises nobody would wait out. A world
that deletes its own signal is stale too (HLT-1).
The plan's order (A5) is the order in which services BECOME ELIGIBLE;
the boot transcript is the order in which they actually start. (Ruled
after OS-2's transcripts interleaved: AFTER had only ordered spawns —
`experiment/PROTOCOL.md`, OS-3.)

**The boot path has no shell.** A RUN whose program is a shell (`sh`,
`bash`, `dash`, `ash`, `zsh`, `fish`, `ksh`, `csh`, `tcsh`) is refused by
name (R5). The real guarantee is the image's — a profile ships no
shell — and this refusal is the grammar's echo of it: the declaration
cannot even ask.

### DEFINE PEER — somebody else on a link this machine serves

| clause | value | obligation |
|---|---|---|
| `NETWORK` | ident | required — a NETWORK declared in this file (R75) that declares a `DOMAIN` (R71) |
| `HARDWARE` | string | required — six pairs of hex, colon-separated (R74): what the machine recognises a returning device by. One device, one name |
| `ADDRESS` | string `"a.b.c.d"` | required — the one address this device is given. It must be on that link (R70), it may not be the machine's own (R73), and no two peers may share one (R72) |

A peer's NAME is its name on the wire, so it must be one: lowercase
letters, digits and the hyphen, not at either end (R76). The estate
writes `makeen_box` with an underscore and DNS cannot carry one, so the
court refuses rather than rewriting — a silently corrected name is a
name the author no longer knows.

**There is no pool and no range.** A machine that declares a `DOMAIN`
serves exactly the peers declared beside it and nobody else: an
undeclared device asking for an address gets silence, and its own
transcript says `no lease after 3 tries (no server answered on this
network)`, which is the truth about a network it was never declared on.

That is the whole design, and it is a removal rather than a feature.
The register of who has which address cannot be lost at a reboot,
because there is no register — there is this file, in git, judged by
the court before the image was built. The lease is offered as INFINITE
(option 51, `0xffffffff`) for the same reason: the address is this
device's because it was declared, not because a timer has not run out.

The machine offers ITSELF as the resolver (option 6) and gives the
domain (option 15), and sends a **router option only if it forwards**
(`FORWARD`, FWD-1): a box that named itself the way out without being
one would be lying to every device on the link. A name it does not
serve is answered `NXDOMAIN`, never forwarded upstream — the box speaks
for its own link, for the links it is the way to (by their FULL names
only: a bare word is a name on THIS link), and is silent about the rest
of the world.

`harb ask <name>` is the witness, and `experiment/os6_names.sh` boots
the pair that proves it: `machines/makeen_names.machine` serving,
`machines/caisse_makeen.machine` asking, and the same image booted a
second time with a hardware address nobody declared, getting nothing.

### DEFINE CAPABILITY — the name is the capability

| clause | value | obligation |
|---|---|---|
| `GRANT` | `yes` \| `no` | required (R23) |

The NAME is drawn from stzlib's closed menu (R16), each on its kind of
the lattice:

| capability | kind |
|---|---|
| `filesystem` `process` `network` `environment` `dynamic_load` `gpio` | effectful |
| `threads` | compute |
| `clock` | sensing |
| `inference` | inference |

**Silence is refusal.** A capability no declaration mentions is not
granted; a service that NEEDS it is refused at check time (R17). A
capability declared `GRANT no` is a stated fact of the machine, printed
in the plan as `refuse`, and needing it is refused too (R18).

### DEFINE MOUNT — a filesystem at an absolute path

| clause | value | obligation |
|---|---|---|
| `AT` | string, absolute (R24) | required |
| `FS` | `proc` `sysfs` `devtmpfs` `tmpfs` `ext4` `vfat` `littlefs` | required; by profile — hosted: all but littlefs; edge: littlefs, vfat, tmpfs (R22); touch: no mounts at all (R26) |
| `DEVICE` | string | required for ext4, vfat, littlefs (R29) |
| `OPTIONS` | name list from `rw` `ro` `noatime` `nosuid` `nodev` `noexec` | optional |

The hosted profile mounts `proc`, `sysfs`, `devtmpfs` IMPLICITLY before
any declared mount; the plan prints them marked implicit.

### DEFINE PIN — a GPIO line

| clause | value | obligation |
|---|---|---|
| `GPIO` | number | required |
| `MODE` | `in` \| `out` | required |

A PIN requires the `gpio` capability declared and granted (R20). The
touch profile owns no pins.

## The checks (the court)

1. Closure at every layer — verb, kind, clause, every menu value: each
   refused by name, with the line.
2. One MACHINE, first.
3. One namespace, no duplicates (R7).
4. Profile coherence — kernel, libc, filesystems, mounts, pins.
5. References resolve at check time — AFTER to a service, NEEDS to a
   granted capability; no self-reference, no cycle.
6. Required clauses present; value shapes as tabled.

## The refusal channel

`machine (line N): message` — one shape for tokenizer, parser and
check refusals. Every refusal names its reason and the fixtures carry
the fragment each must contain: refusing for the wrong reason is a
failure, and the court's first run convicted this very implementation
on one refusal's wording (PINNING.md).

## The derived plan

From a judged machine, in this order: the console; the profile's
implicit mounts; the declared mounts in declaration order; every
capability, granted or refused; the pins; the services in AFTER order,
declaration order breaking ties (A5). The plan is text before it is an
act — stzlib's rehearse-plan-commit law carried down to the boot.

## Refused, by design

- No shell, no command string, no eval: a service is an argv.
- No logic: nothing in a `.machine` file computes, loops or branches.
- No package manager, no init scripts, no `ExecStartPre`: what a
  machine runs is the closed list of its SERVICE declarations.
- No open escape form: no clause denotes host code or I/O.

## Named seams (stated, not hidden)

- **What a world may SEE** — since NS-1, MNT-1 and PID-1 the kernel
  holds a world to what its `NEEDS` left out: no `network` is an empty
  network namespace, no `filesystem` is a mount namespace with every
  declared MOUNT detached, and no `process` is both a seccomp filter on
  fork and a process table of the world's own, where the other worlds
  have no pids at all. `process` is stzlib's "spawn and manage", and
  managing is inspecting and signalling as much as starting. Still open:
  `threads`, which is read and deliberately not enforced at the kernel
  and never will be here: it asks WHO ASKED for a thread, which only the
  runtime knows. Since THR-1 the question a floor can answer has its own
  clause -- `TASKS`, how many the machine will hold -- and the capability
  stays the runtime's to refuse. Per-world choice of which mount to keep
  is `SEES` since SEE-1.
- **What no world may do at all** — SYS-1 refuses every world, whatever
  it declared, the calls that would let it change the machine it runs
  on: mount and unmount, the module and kexec calls, reboot, the clock
  setters, the host name, `unshare` and `setns`, `ptrace`, swap, `bpf`,
  `syslog`, `acct` and `mknod`. No clause grants these because no
  declaration should ask. It is a named closed DENY list and not a claim
  that everything else is safe; a default-deny allowlist is the strong
  form and is not built.
- **Users and identities** — every service runs as the machine today;
  a USER seat with the machine's identity model (MicroRing's Ed25519
  per device is the precedent) is a fixture-first widening.
- **Network declaration** — done (NET-1). What is still queued on it:
  wifi credentials by reference, IPv6, and lease RENEWAL (a served
  address is infinite by declaration, but a leased one is not).
- ~~**Forwarding** — a machine that serves a link does not route between
  links. A `FORWARD` clause would be an act and would be declared; none
  exists, so no machine forwards.~~ **Closed (FWD-1)** by `FORWARD`:
  declared, read back, and judged by a boot of three machines on two
  wires. What is still open: **a packet filter** (a machine that
  forwards filters nothing, and says so in its boot line), and a
  forwarder's per-NIC hardware addresses, which no declaration can say.
- **Edge boot** — the edge profile is declarable and judged, not yet
  bootable: its substrate is MicroRing's (MicroZig, the flash
  filesystem), and `harb init` refuses it by name.
- **Touch** — declarable, judged; the AOSP profile is ZinOS Touch's
  design, unbuilt.
- **A solution's services** — since PLC-1 they can be written apart from
  any machine, in a pack, and placed on one by `harb place`, which hands
  the composed text to THIS court: a pack's `NEEDS`, `SEES`, `USER` and
  `AFTER` are judged by the rules above and by nothing else. A pack is a
  third file of this language; see `declarative/pack/GRAMMAR.md`.
- **The image** — `harb image` (kernel + this binary + the declared
  services into one bootable artifact) is the next act; see
  `doc/ARCHITECTURE.md`.

## Conformance

`fixtures.json` beside this file is the judge: 8 accepts with structural
expectations, 32 rejects with expected fragments. One runner exists
today:

- Zig: `zig build court` (parser: `src/machine.zig`, plan: `src/plan.zig`)

PINNING: see `PINNING.md` beside this file.
