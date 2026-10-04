# fleet v0.2 — pinning and the conformance scoreboard

## The pin

`fixtures.json` sha256:

```
aeea0175e8c39dd833c74130bd16b41cd6fc3a71467a60ba4e9f01cb30980739
```

(Before the ROUTE seat of 2026-10-04 (FWD-1, fleet v0.2):
`9c5e200f0167bdbb61cf0894580fe919f56b13398ceac0c45535b75576c3ac6b`,
32/32; the widening added FA7-FA10 and FR27-FR48, gave the fleet its
fourth kind and `FLEET` its `LINKS`, and took FA7 verbatim from the real
files of the smallest cloud. Before the RETIREMENT seat of 2026-09-26 (RET-1):
`bb1f8349ec64fc458b5a4c6a80dbd30a8ab400cf853640080ae134c4730e4c3b`,
22/22; the widening added FA5-FA6 and FR19-FR26, gave the fleet its
third kind, and made FR5 compare keys rather than their spelling.
Before the HARDWARE clause of 2026-09-14 (HDW-1):
`caafed59342bc87c75efe291696eb4c493ff7a6a1af72048fa1aadb9454c0dee`,
16/16; the widening added FA4 and FR14-FR18, and gave MEMBER its
`HARDWARE`.)

Born at 16/16 with the fleet court of 2026-09-14 (FLT-1). Re-pin this
digest in the same commit that changes `fixtures.json`, as the machine
grammar's own `PINNING.md` requires of itself.

## Scoreboard

| runtime | how | conformance |
|---|---|---|
| Zig (`src/fleet.zig`) | `zig build court` / `harb court --fleet` | **58/58** — 10 accepts, 48 rejects (32/32 before ROUTE; the first run of the widening was 56/58, and the two it refused were MY fixtures, each for the wrong reason, so the court convicted its own author twice before it was green) |

`zig build court` runs BOTH grammars: the machine fixtures first, the
fleet fixtures after. One step, two courts, because a fleet is no better
than the machines in it and a change to either can break the other.

## What is different about a fleet fixture

A machine fixture is one source string. A fleet fixture is a SET, so
each case carries the machine files it names **inside itself**:

```json
{
  "id": "FR8",
  "source": "DEFINE FLEET ... MEMBER box ... MEMBER autre ...",
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
That script now reads both addresses through `harb fleet <file>
hardware <member>`, and the proof is that **the 66-line names pin
matched unchanged** on the first run afterwards: the declaration
supplies exactly what the constants did, and now the court can check it.

## The ways between links: ROUTE (FWD-1, fleet v0.2)

`LINKS [front, core]` names several wires where `LINK` named one, and
`ROUTE` says two of them are joined and through whom. Twenty-two cases
hold it (FA7-FA10, FR27-FR48), and the interesting ones are the ones no
single machine can fail:

- **the door** (FR39, FR40): a machine that says `FORWARD` joins every one
  of its links, whether or not anybody meant it to. The fleet must say it
  was meant, for EVERY pair, or the box is a door nobody agreed to;
- **the way is a machine of the set** (FR34-FR38): on every link it joins,
  with an address others can send to, and it forwards -- a way that does
  not forward is a wall, and a route over it is a promise nothing keeps.
  One way between two links (FR38): a member has one gateway, and cannot
  be sent through two;
- **everyone takes the way, or leaves the link** (FR42-FR47): a route is
  a way BOTH ways, because no filter exists to make it one-way and an
  answer needs a way back as much as a question needs a way there. So a
  member of a joined link has a gateway that IS the way (FR42, FR43,
  FR44), is told the way by a lease from the one machine that can offer it
  -- the link's own server (FR45) -- and does not say there is none
  (FR46), and its perimeter reaches the other links (FR47). A till whose
  route is right and a server with no way back are each faultless alone;
- **a route to nowhere** (FR48): a destination that is a declared link no
  route joins to this one is a claim that a way exists, and the fleet is
  the one place that knows it does not;
- **one wire has one prefix** (FR41), because machines that disagree where
  a wire ends are each faultless alone.

FA7 is `machines/cloud_links.fleet` and the three machine files it names,
VERBATIM, taken mechanically from the files: the court judges the real
smallest cloud, and `experiment/os8_links.sh` boots it. FA9 is the
other half: a link no route joins asks nothing of its members.

The first run of this widening was 56/58, and the two cases the court
refused were the fixtures' own -- FR44 and FR45 each tripped an EARLIER
rule (a forwarder on the link is itself a member that must take the
other route; a server of a joined link is itself a member that must
declare its gateway), so each refused for a reason that was true and was
not the one the case was written for. A court that refuses for the wrong
reason is not a court of that rule, and its author is the first thing it
convicts.

## The court judges this pin (PIN-1)

A pin is a claim that these verdicts are about ONE file, and until
2026-09-26 nothing received it: the rule "re-pin in the same commit that
changes `fixtures.json`" was kept by people remembering, and the rename
of 2026-09-20 forgot it for the machine grammar. The court now hashes the
fixtures before it judges a case and refuses to call the result
conforming when the pin names another file -- the verdict reaches the
exit code (VDCT-1), so `zig build court` fails on a stale pin even when
every case passes.

## Retirement: a key a member USED to have (RET-1)

`RETIREMENT` names a member, a key it held, and the one entry that key is
trusted THROUGH. Eight refusals hold it (FR19-FR26):

- a retirement of nobody (FR19), a key that is not a key (FR20), a head
  that is not the hash exactly as the journal writes it (FR21 -- a head
  differing only in case would never be reached, and the refusal would
  come at verify time, years later, for the wrong reason);
- **a retirement with no head at all (FR22)** -- the refusal that is the
  whole design: a retired key with no entry it is trusted through
  vouches for whatever its holder signs next;
- a key both held and retired (FR23), retired while it is another
  member's (FR24), or retired twice (FR25);
- and FR26, which is FR5 corrected: one key, one place, compared as a
  KEY. FR5 compared the text, so `aa..` and `AA..` -- one key -- passed
  as two, and a retirement check built on the same comparison would
  have inherited the hole.

## The checks these fixtures exist for

Every reject is a case where **each machine is faultless alone**. That
is the whole justification for a second file, and FR8 is the clearest:
two boxes that each declare themselves the server of `makeen` both pass
`harb check`, and the network they make is broken. `src/fleet.zig`'s
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
