# fleet v0.1 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
bb1f8349ec64fc458b5a4c6a80dbd30a8ab400cf853640080ae134c4730e4c3b
```

(Before the HARDWARE clause of 2026-09-14 (HDW-1):
`caafed59342bc87c75efe291696eb4c493ff7a6a1af72048fa1aadb9454c0dee`,
16/16; the widening added FA4 and FR14-FR18, and gave MEMBER its
`HARDWARE`.)

Born at 16/16 with the fleet court of 2026-09-14 (FLT-1). Re-pin this
digest in the same commit that changes `fixtures.json`, as the machine
grammar's own `PINNING.md` requires of itself.

## Scoreboard

| runtime | how | conformance |
|---|---|---|
| Zig (`src/fleet.zig`) | `zig build court` / `stzos court --fleet` | **22/22** — 4 accepts, 18 rejects |

`zig build court` runs BOTH grammars: the machine fixtures first, the
fleet fixtures after. One step, two courts, because a fleet is no better
than the machines in it and a change to either can break the other.

## What is different about a fleet fixture

A machine fixture is one source string. A fleet fixture is a SET, so
each case carries the machine files it names **inside itself**:

```json
{
  "id": "FR8",
  "source": "DEFINE FLEET ... DEFINE MEMBER box ... DEFINE MEMBER autre ...",
  "files": { "box.machine": "...", "autre.machine": "..." },
  "refusal": "already serves salle"
}
```

The parser takes a `Resolver` rather than reading the disk: the court
hands over the fixture's own texts, the CLI reads files beside the fleet
file. A fixture stays one self-contained case and the court needs no
scratch directory.

## The join, and the constant it replaced (HDW-1)

`HARDWARE` on a MEMBER says which physical unit it is, and five
refusals hold the promise against the machine: hardware that is not an
address (FR14), two members claiming one device (FR15), a device that
asks on a served link and is in nobody's register (FR16), a device
promised one address that takes another (FR17), and a server that
appears in its own register (FR18). **22/22**, from 16/16.

What it removed is worth more than what it added. The correspondence
between the address `makeen_names` promises and the device that claims
it lived in a `-device ...,mac=` flag in `experiment/os6_names.sh`.
That script now reads both addresses through `stzos fleet <file>
hardware <member>`, and the proof is that **the 66-line names pin
matched unchanged** on the first run afterwards: the declaration
supplies exactly what the constants did, and now the court can check it.

## The checks these fixtures exist for

Every reject is a case where **each machine is faultless alone**. That
is the whole justification for a second file, and FR8 is the clearest:
two boxes that each declare themselves the server of `makeen` both pass
`stzos check`, and the network they make is broken. `src/fleet.zig`'s
third unit test states it by declaring both machines successfully and
then refusing the fleet.

## Attribution, judged beside the code

Three unit tests in `src/fleet.zig`:

- a box verifies another device's record holding **nothing but its
  public key** — three chained entries, signed by a key the verifier
  does not have, verified;
- a member with no key enrolled is `not_enrolled`, never guessed; a name
  that is not a member is `no_such_member`;
- one word changed in an entry (the verdict) is caught with its
  position, and the same record offered as another device's is refused.

And the arc end to end on a real device, pinned at **26 lines**
(`machines/fleet.expected`, `experiment/os7_fleet.sh`): a key made on
first boot, published with `attest --export`, enrolled by hand, and the
record verified by a process that never held the secret — then the same
three negatives against the real artifacts.

The device makes a NEW key on every run of that script, and the pin
still holds, which is the point: each distinct key becomes `KEY1`,
`KEY2`, … in order of appearance, so the persistence claim survives the
normalisation and only the randomness is erased.

## The defect the first run of that script exposed

The normaliser matched `fingerprint [0-9a-f]+` and the transcript
contained `fingerprint after its next boot` — so it read the `af` of
`after` as a fingerprint and wrote a normalised token into the middle of
an English word. Values are now MARKED by `sed` at their exact lengths
(64 hex for a key, 16 for a fingerprint) before `awk` maps the distinct
ones. The same fragility was in `experiment/os2_image.sh` since IDN-1,
unexposed only because no line there put a word after `fingerprint`.
