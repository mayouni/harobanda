# The Cloud — a fleet that spans links and places packs

*Written 2026-10-04 from the author's question -- how the declared
machine is composed into an industry-grade cloud for solutions built
on the Softanza platform -- and his two rulings on the answer,
STZ-OS-RULING-14 and 15 in `doc/PROVENANCE.md`. Read `doc/GROUND.md`
first for what the machine is for, and `doc/DIVIDEND.md` for what the
floor gives each layer; this document says how the floor is composed
into many machines that serve one solution, in what order the parts
are built, and what is deliberately left unbuilt. Every rung carries
its status, so that the Enterprise page's sentence and the code can be
read against each other at any time.*

## 1. The two names

**Harobanda Cloud** is what this repository composes: a fleet that
spans several links and places solutions' server packs on its
members, judged by the court before any image is built, with no
control-plane service. It is the floor's composition and nothing
above it.

**Softanza Cloud** is that cloud with Haro, Softanza, Aïcha (the
Softanza language model and conversational agent) and the customer's
own solution stack enabled: the whole stack, from the operating system
to the application, ready for a solution maker to deploy a solution on
as an industry-grade cloud platform. The author's words: *"like we
helped solution makers to get each component ready, from OS to
application, we offer him the full stack ready to deploy his
solution."* It is an offer at the estate's altitude, and its home is
the Vision Corpus's product chapter, which this repository never
edits; it is named here so that the two names never coexist silently
with a third. Both are provisional, like every name here.

## 2. What a cloud is, in this project's words

A cloud here is not a product and not a control-plane service. It is
**a fleet that spans several links and places solutions' server
worlds on its members**. Composing one is writing a fleet file, and
the court judges the file before any image is built. The control
plane is the file in git plus each box's own judge: no daemon to run,
nothing to install, nothing to discover. That is what makes the
composition easy. What makes it industry-grade is the list of
refusals -- the states a set of machines must never be in, each one a
check no single machine can fail (FR1 to FR26 today, in
`declarative/fleet/GRAMMAR.md`).

Composition has two halves:

- **Projection.** A Softanza solution's own declaration is projected,
  by stzp's server target, into a *pack manifest*: the port, the
  mounts, the capabilities, the readiness path, the identity, the
  memory and CPU, and the egress destinations it needs.
  `doc/DIVIDEND.md` §5 already names exactly this as what a server
  pack owes the floor.
- **Placement.** The fleet file says which member runs which pack.
  `harb` derives the SERVICE lines from the manifest and the member's
  own declaration, and judges NEEDS against the manifest (DIVIDEND
  seam 8). Nobody writes a service by hand, box by box.

So a solution maker on the Softanza platform never writes a
deployment: the solution's declaration says what it needs, the fleet
file says where it runs, and the court says whether the two agree.

## 3. What already composes (built, judged, pinned)

- **The world is the unit.** Network, mount and process namespaces and
  the seccomp filter are derived from `NEEDS` (NS-1, MNT-1, PID-1); a
  cgroup budget (BDG-1, THR-1); `READY` and `HEALTH` (SRV-1, HLT-1);
  twenty-five calls refused to every world (SYS-1). It is the
  isolation a container runtime gives, with no runtime.
- **The machine.** One file, one image rebuilt at each boot, two
  slots, a trial before a commitment (AB-1), a per-device key (IDN-1),
  a signed boot journal (JRN-1).
- **The set.** `FLEET` with members, hardware, keys, attribution and
  retirement (FLT-1, HDW-1, RET-1); one link's addresses and names,
  where the declaration is the register (NAM-1).
- **The hosted image already boots as a virtio guest** -- `CONFIG_VIRTIO`
  and its block, net, PCI and MMIO drivers are in the derived kernel
  fragment, and every emulator boot is one. A cloud provider's virtual
  machine is a board, not a new profile.

## 4. What a cloud needs, against what exists

| a cloud needs | today | missing |
|---|---|---|
| a server world | worlds serve and signal (SRV-1) but stand in for the real ones | the Commons, RingServ or stzAppServer as a declared `SERVICE` reading `/etc/machine` |
| machines reaching each other | one `LINK` per fleet; a box serves its link and forwards nothing | `FORWARD` on a machine, a route between links in the fleet, names across links |
| a front | TLS is ruled to a proxy in front; no clause | a front pack: the names it fronts, its key on a declared mount |
| time | the journal carries no timestamp; ruling 07: attested, never assumed | a `TIME` clause naming a declared authority; the journal carrying attested time |
| rollout | an A/B trial per box, self-judged | waves over the set, and the set's own commit |
| reach per world | `EGRESS` writes routes; worlds with `network` share them | per-world egress, and the packet filter |
| one record | each journal signed; `harb fleet attribute` | a witness world that collects and verifies every member's journal, holding no secret |
| an image a provider boots | the emulator is handed the kernel and the initramfs; only the Pi gets a card | an x86 disk image with a boot loader or EFI stub, and the two slots on it |

## 5. The ladder, in the order the dependencies allow

Each rung names the act, the judge and what it buys. The clause names
are proposals until the grammar carries them; `FORWARD` is the word
the machine grammar itself uses for the missing act.

**Rung 1 -- the Commons as the first declared server world.** The
seam `doc/DIVIDEND.md` §5 names, and its candidate: RestoLean's
Commons (identity, catalogue, orders, payments) as a `SERVICE` that
reads its envelope from `/etc/machine`, with `READY` on its first
answer and `HEALTH` on the window it keeps answering. The pack
manifest is judged against the SERVICE: a need the manifest states
and the machine does not grant is refused before the image is built.
*Judge:* a QEMU machine boots it, the trial commits, and `harb
guarantees` reads the promises off its own transcript. *Buys:*
everything after this serves something real. *Status:* not built; the
box's worlds are stand-ins (`machines/makeen_box.machine`).

**Rung 2 -- two links.** `FORWARD` on a machine with two `NETWORK`s
makes it the way from one link to the other; in the fleet file a
route says which member is that way; the resolver answers
fleet-declared names across links, and nothing else -- the box still
speaks for its links and is silent about the rest of the world.
*Judge:* three machines on two wires in the emulator, os6-style: a
front box, a core box, a till on the front link asking for the
Commons by name and reaching it through the box; and a fourth machine
asking from a link it was never declared on, getting nothing. *Buys:*
a front link and a back link, the smallest cloud. *Status:* not
built; `src/names.zig` says so by name.

**Rung 3 -- time, then the front.** `TIME` first, because a
certificate is a dated claim and the floor has no date: a declared
authority (STZ-OS-RULING-07, attested and never assumed), and the
journal carrying attested time beside its sequence. Then the front
pack: a proxy that terminates TLS, as the estate ruled, its key an
asset on a declared mount like `IDENTITY`, fronting the names the
fleet declares. *Judge:* a request from outside the front link reaches
the Commons through the front and nothing else, and the journal's time
is the authority's. *Buys:* a solution reachable from the internet
with a declared surface. *Status:* not built; TLS stays out of the
floor by ruling.

**Rung 4 -- an image a provider's machine boots.** An EFI stub or a
boot loader, the two slots on a disk, a `BOARD` for a generic virtio
virtual machine, `HARDWARE` being the address the provider gives.
*Judge:* the same image booted by the emulator from the disk, the
slot machinery judged as AB-1 judges the card. *Buys:* the same file
runs on a server you own and on one you rent, and sovereignty is
decided per dependency, as the table in `doc/ARCHITECTURE.md` already
does. *Status:* not built; the emulator is handed the kernel directly
(`src/image.zig`).

**Rung 5 -- rollout over the set.** Waves in the fleet file: which
members first, how many at a time. A wave is committed only when every
member in it has committed its own trial, and the set judges itself
as a box does. zin's constitution keeps the policy; the floor keeps
the mechanism. *Judge:* a set of emulated machines given a new image,
one of them refusing its trial, and the next wave never starting.
*Buys:* a thousand boxes updated with one box's discipline. *Status:*
not built; the per-box trial is (AB-1).

**Rung 6 -- per-world egress and the packet filter; the witness
world and the evidence page.** Egress held per world rather than per
machine, and a filter behind the routes (the stronger statement EGR-1
left open). A declared witness world that collects every member's
journal and verifies it with the fleet's public keys, holding no
secret; stzn renders the verdicts as the page an auditor reads.
*Status:* not built; `harb fleet attribute` is the one-record shape.

## 6. What is not built, by the doctrine already paid for

- **No hypervisor in the product.** The emulator is the court's
  instrument (`doc/GROUND.md` §7). Density is more worlds on one
  machine; isolation between owners is more machines; the provider's
  virtual machine is the hardware.
- **No orchestrator daemon, no discovery, no pool.** The file is the
  register (NAM-1), and a service that discovered the set would be a
  second source of truth about it.
- **No automatic enrolment and no autoscaling.** Enrolment by hand is
  the design, because an automatic one would have to trust the wire.
  Capacity is declared; adding a member is one line and one image.
- **No TLS stack and no distributed filesystem at the floor.** TLS
  terminates in front by the estate's ruling; local-first data and
  its sync stay the server's (RingServ's shape log).
- **No second grammar.** A cloud is fleet v0.2 -- routes, placement,
  rollout added to the kinds a fleet file may contain -- never a third
  file. A file is judged by which kinds it may contain.

A sketch of the fleet file rung 2 and rung 5 would ask for, proposed
and refused by today's court:

```
-- proposed fleet v0.2: not in the grammar yet
DEFINE FLEET makeen_cloud AS (
  LINK front,
  LINK back
) RATIONALE "One restaurant group: the boxes in the
    rooms on the front link, the core on the back"

DEFINE MEMBER edge AS (
  DECLARATION "edge_box.machine",
  HARDWARE "52:54:00:12:34:01",
  ON [front, back]
) RATIONALE "On both links, and the only member that
    may forward between them"

DEFINE ROUTE front_to_back AS (
  FROM front,
  TO back,
  THROUGH edge
) RATIONALE "The way from the rooms to the Commons;
    no other member forwards"

DEFINE ROLLOUT nightly AS (
  WAVES [[core], [edge], [till_a, till_b]]
) RATIONALE "The core first, the way second, the
    tills last; a wave that does not commit stops
    the next"
```

## 7. The offer, and what sovereignty survives it

A Softanza Cloud that Softanza *operates* for a customer needs no new
mechanism: the customer's fleet file is the contract, the images are
built from it, and every member's journal is verifiable by the
customer holding no secret. What must be said plainly is which half of
sovereignty that keeps. The customer owns the declaration and the
evidence; Softanza holds the hardware, and whoever holds the hardware
holds the device keys. The honest offer is *"your declaration, our
hardware, your evidence"*, never *"your cloud"*. A customer who wants
the other half runs the same files on hardware of their own, which the
ladder makes the same act.

## 8. Honest boundaries

- No rung is built. Today a fleet has one link, no machine forwards,
  no server is a declared service, there is no front and no clock.
- `site/enterprise.html` says *"the same declared machine can run the
  cloud too. Enterprise-cloud, made easy."* By the author's word
  (ruling 14) the sentence stays and this ladder makes it true; until
  it does, the page's opening covers it as a direction, and this
  document's status lines are where the distance is measured.
- Haro's runtime is not the image's second binary yet, and Aïcha's
  first speech is a declared language's sentence by the alphabet's
  rule; the Softanza Cloud is an offer whose stack is partly at
  charter.
- Rungs 2 and 5 are judged in the emulator, like everything here
  until OS-5; the clock (rung 3) is where the emulator cannot stand in
  for the world, because the authority it attests must be real.

## 9. The first rung, in one session

Rung 1 is the one that can be taken without a grammar change. A
session takes it in this order: the Commons's own needs written as a
pack manifest from its code (its port, its data mount, its readiness
signal, its memory), the SERVICE derived from it on a QEMU machine of
its own, the manifest judged against the machine with one deliberate
mismatch to see the refusal, the boot pinned, and `harb guarantees`
read off it. What it needs from outside this repository: the Commons
binary or its stzr program, which is RestoLean's and RingServ's to
hand over; what they state they need is the manifest, in their words.
