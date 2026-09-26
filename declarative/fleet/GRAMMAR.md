# fleet v0.1 — the grammar of a set of machines

## Why there is a second file and not a bigger one

Every check the machine grammar makes can be made by reading one
machine. Some checks cannot be made that way at all:

- two boxes that each declare themselves the server of `makeen` are each
  a faultless machine, and together they are a network where two
  machines hand out the same addresses;
- two machines that each take `192.168.10.7` are each correct alone;
- a till that asks for an address on a link nobody serves is a till that
  never gets one, and nothing in its own file is wrong.

Those are facts about a SET, so they are declared in a file about a set.

It is the **same language** — the same tokenizer, the same clause
machinery, the same refusal channel, the same mandatory `RATIONALE`. A
file is judged by which kinds it may contain: a machine file that
declares a `FLEET` is refused by name, and a fleet file that declares a
`MACHINE` is refused by name.

## The kinds

### DEFINE FLEET — exactly one, and first (FR1, FR3)

| clause | value | obligation |
|---|---|---|
| `LINK` | ident | optional — the wire these machines share. Within one fleet, every member's `NETWORK` of this name is the same physical link, which is what makes the address checks mean anything. Without it a fleet is an estate and not a network, and only the identity checks apply |

### DEFINE MEMBER — one machine of the set

| clause | value | obligation |
|---|---|---|
| `DECLARATION` | string | required — a `.machine` file, resolved beside this fleet file. It must be readable (FR13) and must itself be judged; a member's own refusal is reported WITH the member, because a line number in a file the reader did not open is not an answer (FR12) |
| `KEY` | string | optional — the member's enrolled Ed25519 **public** key, 64 hex characters (FR6) |
| `HARDWARE` | string | optional — which physical unit this member is, six pairs of hex (FR14). One device, one member (FR15) |

### DEFINE RETIREMENT — a key a member USED to have (RET-1)

| clause | value | obligation |
|---|---|---|
| `MEMBER` | ident | required — the member the key belonged to (FR19) |
| `KEY` | string | required — the retired Ed25519 public key, 64 hex (FR20). One key, one place in a fleet, held or retired (FR23–FR26) |
| `THROUGH` | string | required — the hash of the last entry the fleet trusts this key for: 64 lowercase hex, exactly as `harb fleet … verify` prints it once that record has verified (FR21). Its absence is refused in words that say why (FR22) |

## Enrolment is not prophecy

A `KEY` is absent until the device exists. It cannot be otherwise: the
key is made on the device, on its first boot, from its own randomness
(IDN-1), and a declaration written beforehand cannot know it.

So a member without a key is **not refused** — it is REPORTED. `harb
fleet` names every member that keeps a signed record and has no key, in
those words: *nobody can verify what it signs*. The court refuses what
is wrong; the roll says what is incomplete.

The enrolled key implies the fingerprint the device prints on its own
console at every boot (`sha256(public)[0..8]`), and the roll prints that
fingerprint beside the member, so an operator compares the two by eye.
That is the whole of enrolment and it is deliberately manual: a fleet
that enrolled whatever key answered would attribute records to whatever
device happened to be plugged in.

## Why HARDWARE is here and not in the machine file

A machine file is a DESIGN, and one design images many devices. A
hardware address belongs to one of them. It is the same distinction the
key already makes: both are facts a DEPLOYMENT learns, never facts a
design states, so both live on the member.

What it buys is the join. `machines/makeen_names.machine` promises
`192.168.10.40` to a peer identified by a hardware address;
`machines/caisse_makeen.machine` is the till and says nothing about its
own hardware. Until HDW-1 the only thing connecting the two was a
`-device ...,mac=` flag inside `experiment/os6_names.sh` — the one fact
about that deployment that was not declared anywhere, in a repository
whose whole argument is that such facts must be.

With `HARDWARE` on the member the court holds the promise and the
machine against each other (FR16, FR17, FR18), the roll says which
promise each member answers to, and the script reads the address from
the declaration through `harb fleet <file> hardware <member>` instead
of carrying a constant.

```
caisse -- caisse_makeen (caisse_makeen.machine, asks) -- 52:54:00:12:34:61, promised 192.168.10.40 as caisse
```

A `PEER` that no member claims is NOT refused: the kitchen printer is a
declared peer of the box and will never be a Harobanda machine. The fleet
checks the members it has, and says nothing about the rest of the wire.

## What the fleet refuses (the checks no single machine can fail)

| id | refused |
|---|---|
| FR1 | a fleet file that declares no `FLEET`, or more than one |
| FR2 | a `MACHINE` (or any machine kind) in a fleet file |
| FR3 | a `FLEET` that is not the first declaration |
| FR4 | two members naming the same declaration — the fleet would count one device twice |
| FR5 | two members carrying the same key — a key that appears twice attributes one device's records to two |
| FR6 | a `KEY` that is not 64 hex characters |
| FR7 | two members whose machines share a `MACHINE` name — a signed record names its machine, and two of them would be one name |
| FR8 | two members serving the same `LINK` — one link, one server of names |
| FR9 | two members holding the same static address on the `LINK` |
| FR10 | a member taking an address the link's server has PROMISED to a `PEER` — the promise is the one place an address is written, and a second claim is a second source of truth |
| FR11 | a `LINK` with a member asking by dhcp and no member serving it |
| FR12 | a member whose own declaration is refused |
| FR13 | a member naming a declaration that cannot be read |
| FR14 | a `HARDWARE` that is not six pairs of hex |
| FR15 | two members declaring the same hardware — one device, one member |
| FR16 | a member that asks by dhcp on a served link whose hardware the server has in no `PEER`: it would never get an address, and there is no pool to fall back on |
| FR17 | a member the server promises one address and which takes another itself |
| FR18 | the link's own server declaring hardware that appears in its own register — a server does not ask itself for an address |
| FR19 | a `RETIREMENT` of a member nobody declared — a key is retired FROM a device |
| FR20 | a retired `KEY` that is not an ed25519 public key |
| FR21 | a `THROUGH` that is not the hash exactly as the journal writes it — one differing only in case would never be reached, and the refusal would come at verify time, years later, for the wrong reason |
| FR22 | **a `RETIREMENT` with no `THROUGH`** — a retired key with no entry it is trusted through vouches for whatever its holder signs next |
| FR23 | a key a member still holds, retired — a key is the device's or it is retired, never both |
| FR24 | a retired key that is another member's key — FR5's rule, which a retirement must not become a way around |
| FR25 | a key retired twice |
| FR26 | one key spelled two ways (`aa..`, `AA..`) on two members — FR5 corrected: it compared the TEXT, and hex is case-blind |

## Attribution: one machine verifying another's record

The reason the seat was queued. A device signs its own boot record
(JRN-1) with a key it never sends anywhere, so until now only that
device could verify it — attribution nobody else can test, which is a
claim and not evidence.

```
harb fleet <file.fleet>                              judge the set, print the roll
harb fleet <file.fleet> verify <member> <record>     attribute a signed record
```

`verify` uses **only** the member's public key. No secret takes part, so
the act is available to anyone holding the fleet file: another box on
the wire, the court on a laptop, an auditor years later.

`experiment/os7_fleet.sh` runs the whole arc on a real device and lets
the negatives decide it — a key made and published, a record carried off
the machine, then one word changed in it (the verdict, which is exactly
the field somebody would want to change) caught by position, the same
record offered as another device's refused, and an unenrolled member
reported rather than guessed at.

## Retirement: trusted THROUGH one entry, and the chain draws the line (RET-1)

A device's key is made on its card, and when the card is rebuilt the new
card makes a new key. Every record the old card signed would stop being
checkable -- for a till's records, the one promise the journal exists to
keep. So a fleet records the keys a member USED to have.

A retired key cannot simply stay trusted. The need that queued the seat
was a card that DIED; the danger is a card that was STOLEN, which goes on
signing with the same key. A date would separate what it signed before
from what it signs after, and this floor has no trusted clock. The chain
has no need of one: every entry's hash covers its `prev`, so ONE hash
fixes every entry before it. A retirement names that hash -- the head of
the last record the fleet verified -- and the key is trusted through
that entry and not one further. Whoever holds the old card can go on
signing, but only by EXTENDING the chain, and an extension is refused by
position, however perfectly it chains.

A record that never REACHES the head is refused as well, even when every
entry in it verifies: a shorter record the device really wrote, and a
different chain the key's holder wrote since, both verify under the key,
and only reaching the head tells them apart. Present the record through
its head.

**Where the head comes from.** The verifier prints it, and only once the
chain has verified:

```
fleet atelier -- temoin: its head is entry 1, hash=... -- the entry a RETIREMENT of this key would be trusted THROUGH
```

A head copied out of a file nobody checked is a head somebody else may
have chosen.

**Why a declaration of its own.** Every declaration says why it is there,
and why a key was retired -- a card that failed, a card that went
missing -- is the fact an auditor reading this file years later will
need. The mechanism is the same for both; the RATIONALE is where they
differ.

**Why "retirement" and not "revocation".** Revocation promises the key is
dead. What the fleet can say is exactly how far it is still trusted.

`experiment/os7_fleet.sh` runs it on a real device: the card is rebuilt
(a new disk, a new key), the old key is retired through the head the
verifier printed, both records are heard -- and then the SAVED first card
is booted again. It signs entry 2 with the retired key, and:

```
stolen: fleet atelier -- temoin: entry 2 is not this device's under the key retired as carte_1: it comes after the entry the fleet trusts this retired key through, ...
stolen: fleet atelier -- 1 entry from there on verifies under the retired key all the same: whoever still holds it signed after it was retired
```

## Named seams (stated, not hidden)

- ~~A machine cannot say its own hardware address.~~ **Closed (HDW-1)**
  by putting `HARDWARE` on the MEMBER rather than the machine. What is
  still open: a member's hardware is declared, never OBSERVED, so a
  device plugged in with a different address is caught by the server
  refusing it a lease and not by the court.
- **Forwarding between links** — a fleet declares one `LINK`. A machine
  that routes between two is an act nothing declares yet.
- ~~**Revocation** — nothing records a key a device USED to have.~~
  **Closed (RET-1)** by `RETIREMENT`, trusted THROUGH one entry.
  Still open beside it: a fleet cannot say a retired card's records are
  wanted no longer -- retirement keeps them readable, and nothing yet
  retires the RECORDS.
- **Hardware declared, never observed** remains the first seam above;
  the board is where it first matters, and OS-5's plan closes it before
  the board's first boot.
- **Enrolment by hand** is the design, not a gap. An automatic enrolment
  would have to trust the wire, and this floor does not.

## Conformance

`declarative/fleet/fixtures.json`, pinned by sha256 in `PINNING.md`
beside it, judged by `zig build court` (which runs both grammars) or
`harb court --fleet`. Every reject carries the fragment its refusal
must contain, so a runtime refusing for the WRONG reason fails.
