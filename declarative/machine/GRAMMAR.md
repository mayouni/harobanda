# machine — the machine declaration language, v0.1

A `.machine` file declares a machine whole: its profile, the
capabilities it grants and refuses, its mounts, its pins, and the
services it keeps alive. It declares; it does not compute. From a judged
declaration the boot plan is DERIVED (`stzos plan`), and on a hosted
machine the same binary executes that plan as PID 1 (`stzos init`).
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
declaration = "DEFINE" kind IDENT "AS" "(" [ clauses ] ")" rationale ;
kind        = "MACHINE" | "SERVICE" | "CAPABILITY" | "MOUNT" | "PIN" ;
rationale   = "RATIONALE" STRING ;                       (mandatory)

clauses     = clause { "," clause } [ "," ] ;
clause      = CLAUSE_NAME value ;
value       = STRING | IDENT | NUMBER | name_list | string_list ;
name_list   = "[" [ IDENT  { "," IDENT  } [ "," ] ] "]" ;
string_list = "[" [ STRING { "," STRING } [ "," ] ] "]" ;
```

The value shape of every clause is fixed by its name (tables below); a
clause outside its kind's table is refused naming the allowed set
(R12); a clause given twice is refused (R30). `DEFINE` is the one verb
(R1, R3).

## The five kinds

### DEFINE MACHINE — exactly one, and first (R9, R10)

| clause | value | obligation |
|---|---|---|
| `PROFILE` | `hosted` \| `edge` \| `touch` | required |
| `ARCH` | `x86_64` \| `aarch64` \| `riscv32` \| `riscv64` \| `thumbv7em` | required (R11) |
| `KERNEL` | `linux` \| `none` \| `android` | required; must agree with the profile (R15) |
| `LIBC` | `musl` \| `none` \| `bionic` | optional; defaults by profile; a contradiction is refused (R31) |
| `BOARD` | `qemu_pc` \| `qemu_virt` \| `rpi4` | optional, hosted only (R35); defaults by ARCH (`x86_64` → `qemu_pc`, else `qemu_virt`); a board of another architecture is refused (R33); an unknown board is refused (R34) |
| `CONSOLE` | string | optional; defaults `/dev/console`, `uart0`, `logcat` by profile |

The BOARD names what the image is built for: the emulator court's
machines (`qemu_pc` on x86_64, `qemu_virt` on aarch64) or a real board.
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

### DEFINE NETWORK — one interface, one way to an address

| clause | value | obligation |
|---|---|---|
| `INTERFACE` | string | required — the interface's name (`"eth0"`); one network per interface (R39) |
| `ADDRESS` | `dhcp` \| string `"a.b.c.d/n"` | required — a leased address, or a static address with its prefix; an address without its prefix is refused (R38) |
| `GATEWAY` | string `"a.b.c.d"` | optional, static only — a dhcp network learns its gateway (R37); not an address is refused (R40) |
| `DNS` | string list | optional, static only — the servers; a dhcp network learns them |

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
`on_failure` is a daemon: it is ready as soon as it has been spawned.
The plan's order (A5) is the order in which services BECOME ELIGIBLE;
the boot transcript is the order in which they actually start. (Ruled
after OS-2's transcripts interleaved: AFTER had only ordered spawns —
`experiment/PROTOCOL.md`, OS-3.)

**The boot path has no shell.** A RUN whose program is a shell (`sh`,
`bash`, `dash`, `ash`, `zsh`, `fish`, `ksh`, `csh`, `tcsh`) is refused by
name (R5). The real guarantee is the image's — a profile ships no
shell — and this refusal is the grammar's echo of it: the declaration
cannot even ask.

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

- **Users and identities** — every service runs as the machine today;
  a USER seat with the machine's identity model (MicroRing's Ed25519
  per device is the precedent) is a fixture-first widening.
- **Network declaration** — `network_up` is a service in A2 because the
  interface is not yet declarable; a NETWORK kind (address, dhcp,
  wifi credentials by reference) is queued.
- **Edge boot** — the edge profile is declarable and judged, not yet
  bootable: its substrate is MicroRing's (MicroZig, the flash
  filesystem), and `stzos init` refuses it by name.
- **Touch** — declarable, judged; the AOSP profile is ZinOS Touch's
  design, unbuilt.
- **The image** — `stzos image` (kernel + this binary + the declared
  services into one bootable artifact) is the next act; see
  `doc/ARCHITECTURE.md`.

## Conformance

`fixtures.json` beside this file is the judge: 8 accepts with structural
expectations, 32 rejects with expected fragments. One runner exists
today:

- Zig: `zig build court` (parser: `src/machine.zig`, plan: `src/plan.zig`)

PINNING: see `PINNING.md` beside this file.
