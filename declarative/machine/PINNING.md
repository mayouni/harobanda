# machine v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
0448842222d40d7b8d6b4866c23f42c878eda7c9ea83f6c1717eb3fb7789e9cb
```

The machine language's canonical home is THIS repository (like W and
stzu in stz): the fixtures are born here and forked nowhere. Changing
them means re-computing this digest in the SAME commit. A runner cites
the digest it passed against; drift is then a diff, never a surprise.

## Scoreboard

| host | runner | 2026-09-12 |
|---|---|---|
| Zig (`src/machine.zig` + `src/plan.zig`) | `zig build court` / `stzos court` | **40/40** — 8 accepts with structural expectations, 32 rejects with expected refusal fragments (39/40 on the first run: see the conviction below) |

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
