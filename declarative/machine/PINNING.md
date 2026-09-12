# machine v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
0994dccb4bdf4b6d2dae8bfb9174c4b4df76ddc753624d30fd4105e19350bf81
```

(Before the NETWORK kind of 2026-09-12 (NET-1):
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
| Zig (`src/machine.zig` + `src/plan.zig`) | `zig build court` / `stzos court` | **51/51** — 11 accepts with structural expectations, 40 rejects with expected refusal fragments (39/40 on the first run of the v0.1 floor, 43/44 on the first run of the BOARD widening, 51/51 on the first run of the NETWORK widening) |

The language's own declaration, `machine.stzu`, judged by stz's
meta-court (`face/stz/Stzu.luau`, run by stz's `stzr`):
**accepted first run** — 5 declarations, 4 forms, 0 expressions,
3 refusals, verbs CAPABILITY MACHINE MOUNT PIN SERVICE.

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
