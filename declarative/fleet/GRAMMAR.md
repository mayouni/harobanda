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

## Enrolment is not prophecy

A `KEY` is absent until the device exists. It cannot be otherwise: the
key is made on the device, on its first boot, from its own randomness
(IDN-1), and a declaration written beforehand cannot know it.

So a member without a key is **not refused** — it is REPORTED. `stzos
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
the declaration through `stzos fleet <file> hardware <member>` instead
of carrying a constant.

```
caisse -- caisse_makeen (caisse_makeen.machine, asks) -- 52:54:00:12:34:61, promised 192.168.10.40 as caisse
```

A `PEER` that no member claims is NOT refused: the kitchen printer is a
declared peer of the box and will never be an stzos machine. The fleet
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

## Attribution: one machine verifying another's record

The reason the seat was queued. A device signs its own boot record
(JRN-1) with a key it never sends anywhere, so until now only that
device could verify it — attribution nobody else can test, which is a
claim and not evidence.

```
stzos fleet <file.fleet>                              judge the set, print the roll
stzos fleet <file.fleet> verify <member> <record>     attribute a signed record
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

## Named seams (stated, not hidden)

- ~~A machine cannot say its own hardware address.~~ **Closed (HDW-1)**
  by putting `HARDWARE` on the MEMBER rather than the machine. What is
  still open: a member's hardware is declared, never OBSERVED, so a
  device plugged in with a different address is caught by the server
  refusing it a lease and not by the court.
- **Forwarding between links** — a fleet declares one `LINK`. A machine
  that routes between two is an act nothing declares yet.
- **Revocation** — a fleet records the key a device has. Nothing yet
  records a key it USED to have, which is what a device rebuilt on a new
  card needs if its old records are to stay readable.
- **Enrolment by hand** is the design, not a gap. An automatic enrolment
  would have to trust the wire, and this floor does not.

## Conformance

`declarative/fleet/fixtures.json`, pinned by sha256 in `PINNING.md`
beside it, judged by `zig build court` (which runs both grammars) or
`stzos court --fleet`. Every reject carries the fragment its refusal
must contain, so a runtime refusing for the WRONG reason fails.
