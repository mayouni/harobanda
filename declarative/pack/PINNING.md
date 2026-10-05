# pack v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
f30bd423e00b5d42a100ad57efc1d0a9a4e2aa63568d789df5d8b7914247f05b
```

Born at 30/30 with the pack court of 2026-10-04 (PLC-1); 35/35 since the
STATE seat of 2026-10-05 (OWN-1), from
`6420fe4816c726eb09d546dfb1ef4d750d254670f2feadb1cc22aa8fdd2b3ff5`: the
Commons pack (PA1, PA5) now signals inside a directory it owns, because a
world that runs as an identity may no longer signal in root's /run, and
the widening added PA7 (a world owns a directory on a mount the machine
granted it) and PR25-PR28 (a STATE on storage the pack never asked for, a
signal where no identity can write, a directory that is a piece of one the
machine's own service owns, and one that holds the machine's own signal),
each refused at the pack's own line: where two claims conflict, the court
reports the LATER one, which is the pack's when a pack was placed on a
machine that passed alone. Re-pin this
digest in the same commit that changes `fixtures.json`, as the machine
grammar's own `PINNING.md` requires of itself. The court judges the
pin (PIN-1): a stale one fails even when every case passes.

## Scoreboard

| runtime | how | conformance |
|---|---|---|
| Zig (`src/pack.zig`) | `zig build court` / `harb court --pack` | **35/35** — 7 accepts, 28 rejects |

`zig build court` runs ALL THREE grammars: the machine fixtures first,
the fleet fixtures after, the pack fixtures last. One step, three
courts, because a pack is placed on a machine the machine court judges,
and a change to the machine grammar can break a placement.

## What is different about a pack fixture

A machine fixture is one source string and a fleet fixture is a set of
them. A pack fixture is a MACHINE AND THE PACKS PLACED ON IT, carried
inside the case, and a reject says where its refusal must land:

```json
{
  "id": "PR14",
  "machine": "DEFINE MACHINE closed AS (...)",
  "packs": [{ "path": "echo.pack", "source": "..." }],
  "in": "echo.pack",
  "line": 4,
  "refusal": "which no declaration grants"
}
```

The machine is always `host.machine` in the court, and each pack
carries its own file name. `in` and `line` are what make a refusal
that points at the wrong file, or at a line of the composed text the
reader never wrote, fail: a placement refused for the right reason at
the wrong place sends a person to the wrong file.

## What every accept must also be

The court judges three things of ANY placement, so no case has to
repeat them and none can forget:

- the placed text starts with the machine file as written, byte for
  byte;
- placing again gives the same bytes;
- the placed machine has a boot plan (`plan.derive`).

## The lines were read, not copied

Every `line` in a reject was checked against its source by hand
before it was pinned, because a PIN is a claim that what happened was
RIGHT (SYS-1). The first run was green at 27 of 27, which is when a
court deserves doubt: it was probed with mutations of the code, one at
a time, each in a scratch copy of the source (the list is at the foot
of `experiment/PROTOCOL.md`'s PLC-1 entry), and one case, PR24, was
corrected when its first draft carried a fragment that was a guess and
a line that was the wrong quote.
