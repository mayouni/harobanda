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
  thirty calls refused to every world (SYS-1, PRI-1). It is the
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
| machines reaching each other | **built (FWD-1):** `FORWARD` on a machine, `LINKS` and `ROUTE` in the fleet, names across the links a box is the way between; two links, one forwarder, plain HTTP | a chain of forwarders (transit), a way that is one-way (needs the packet filter of rung 6), a forwarder's own hardware addresses |
| a front | TLS is ruled to a proxy in front, and the proxy is **Caddy** (STZ-OS-RULING-18, 2026-10-18); **the port half built (PORT-1):** a world binds the ports it declares and no other, and is given a port below 1024 only if it declares one | Caddy vendored by digest, staged, and placed by a front pack: the names it fronts, its keys on a directory it owns |
| time | **built (TIME-1), in the emulator:** a fleet's one time authority signs that an entry of a record existed no later than a time it read from a clock it has; the asking machine keeps the statement beside its record; ruling 07: attested, never assumed | a board's real clock (OS-5), authenticated network time as a source (NTS), a lower bound |
| rollout | an A/B trial per box, self-judged | waves over the set, and the set's own commit |
| reach per world | `EGRESS` writes routes; worlds with `network` share them | per-world egress, and the packet filter |
| one record | each journal signed; `harb fleet attribute`; **the reading is built (ROLL-1):** `harb roll` reads what members were brought against the fleet's keys and its time authority's statements, and against the roll before it | the collecting: a witness that fetches every member's journal (the floor moves no record between machines), and the evidence page |
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
everything after this serves something real. *Status:* the placement
half is BUILT (PLC-1, 2026-10-04): the pack file and `harb place`, judged
by `declarative/pack/` at 30 of 30 -- a need the machine does not grant
is refused at the line of the pack that asked, before any image is
built. *Amended the same day (SRV-2):* the server half is built too, for
the server the author named, RingServ (future HaroServ): RingServ 0.9,
from its own source at a pinned ref, is placed on `machines/qemu_cloud.machine`
by `machines/ringserv.pack`, boots under PID 1 as a confined world with
a measured readiness, and its boot is pinned and stable
(`experiment/os9_cloud.sh`, `machines/qemu_cloud_ringserv.expected`). What
is NOT done: no customer's server (the Commons is RestoLean's to hand
over, and RingServ here stands in for it, as the Luau worlds stand in for
the box's); readiness is a stand-in program, `harb ready`, because
RingServ writes no ready file (a native `--ready-file` is asked of its
desk); and nothing outside the machine can ask the
server a question yet, since it listens on the machine's own loopback
(rung 3 is its front). The box's own worlds are still stand-ins
(`machines/makeen_box.machine`). *Amended 2026-10-05 (OWN-1): the world
no longer runs as root, which this paragraph listed as not done. It runs
as `appserver` (2000:2000) and owns two directories PID 1 makes and
hands over before it starts (`STATE`, judged by the court): `/run/ringserv`
for its signal and `/data/ringserv` for what it keeps. The pinned boot is
49 lines and reads the directory back from the disk it leaves; the same
image with no disk behind the mount does not start the world. What is
still not shown by a boot: the server's database FILE, because creating a
table at startup took longer than RingServ's own 2000 ms wait under the
emulator, as root too; that it keeps one there as an unprivileged user
was measured outside the machine (`experiment/ringserv_nonroot.sh`).*

**Rung 2 -- two links.** `FORWARD` on a machine with two `NETWORK`s
makes it the way from one link to the other; in the fleet file a
route says which member is that way; the resolver answers
fleet-declared names across links, and nothing else -- the box still
speaks for its links and is silent about the rest of the world.
*Judge:* three machines on two wires in the emulator, os6-style: a
front box, a core box, a till on the front link asking for the
Commons by name and reaching it through the box; and a fourth machine
asking from a link it was never declared on, getting nothing. *Buys:*
a front link and a back link, the smallest cloud. *Status:* BUILT
(FWD-1, 2026-10-04), with one limit named below. `FORWARD yes` on a
machine (the kernel's own switch, read back before the boot says so);
fleet v0.2, `LINKS` and `ROUTE` (60 of 60, 24 of them new); the box's
lease names it the router and its resolver answers for the full names on
the links it is the way to; and `experiment/os8_links.sh` boots the
smallest cloud on two wires, pinned at 148 lines (146 before OWN-1 took
the server off root) and identical on two runs. **A till on the front link asks for `commons.core.cloud`, is told
`10.20.0.2`, connects to it through the box, and RingServ on the core link
answers `/health` with 200.** The two negatives are the same till: a
device nobody declared gets no lease and so no router and no resolver (the
register's reach, and no more: a device that chose its own address and
set the box as its gateway would be carried, because forwarding filters
nothing), and a box without its one clause is silent about the far link. What is NOT shown,
and why: a name that resolves while the way is closed cannot be declared,
because the names follow the way and not the other way round, so the
closed round shows the silence and no round shows a packet dropped by a
box that forwards nothing; the route is a way both ways, since no packet
filter exists to make it one-way (rung 6); a link is joined through ONE
machine, so a chain of two forwarders is not declared; and the server
is reached over plain HTTP between members of one cloud, behind a TLS
front that is rung 3 and is not built.

**Rung 3 -- time, then the front.** `TIME` first, because a
certificate is a dated claim and the floor has no date: a declared
authority (STZ-OS-RULING-07, attested and never assumed), and the
journal carrying attested time beside its sequence. Then the front
pack: a proxy that terminates TLS, as the estate ruled, its key an
asset on a declared mount like `IDENTITY`, fronting the names the
fleet declares. *Judge:* a request from outside the front link reaches
the Commons through the front and nothing else, and the journal's time
is the authority's. *Buys:* a solution reachable from the internet
with a declared surface. *Status:* the time half is BUILT (TIME-1,
2026-10-05), in the emulator, with its limits named below; of the front,
the port is built (PORT-1, 2026-10-14: a world is held to the ports it
declares, and given a port below 1024 only if it declares one) and the
proxy, Caddy (STZ-OS-RULING-18), is placed and judged on one machine
(FRONT-1, 2026-10-19: a world that is not root ends TLS on 443 under a
root it was given by hand, reaches the server behind it in plain HTTP on
the loopback, and refuses a plain question on the TLS port), and then on
the gateway of two links (FRONT-2, 2026-10-19): fleet v0.3's `FRONT`
names the member that is the DOOR of a link -- by the name it has there,
derived from the link's server and never written twice, and under a root
named by its fingerprint -- and the same pack is placed on the box of
`machines/cloud_links.fleet`; the root is made by hand, seeded on the
box's disk and enrolled into a copy of the fleet, and the till asks
`https://front.cloud` through the door, trusting the root's public half
it was given and nothing else, so the fingerprint its line prints is the
one the fleet declares. The box with `FORWARD` taken out still answers at
the door: a front is a way of its own, which is why the fleet declares it
as it declares a route. Rung 3b is BUILT, in the emulator
(`machines/cloud_links.expected`, 202 lines, the roll and the three
machines over three rounds); TLS stays out of the floor by ruling, and
what a device trusts is a file in its image that the scene, not the
court, holds to the fleet's word.

*The time half, as built.* `CLOCK` on a machine names the clock it HAS (a
device), `TIME_AUTHORITY` on one of its links makes it that link's time
authority, and the fleet's own `TIME_AUTHORITY` names the one member whose
word dates its records, enrolled like any member. A machine with a journal
asks (`TIME_FROM`, `TIME_KEY`) once it has written an entry, and keeps the
answer beside the record only if it is the authority's signed word about
THAT entry. What a statement says is an upper bound -- the entry whose
digest is D existed no later than T, and what every entry before it says
with it -- and D is the digest of the entry's whole written line, signature
and all: the entry's own hash is a hash of public bytes, which anybody could
have computed, and asked the time of, before the device had written it. The
entries after the last statement are ORDERED and UNDATED, in those words.
`harb time verify` checks a statement and binds it to a record with the
fleet file alone, and `harb journal` says the same from inside the machine
(for a machine that asks nobody, from its second boot on, that its record
is ORDERED and UNDATED), reporting a kept statement that does not verify
without failing on it.
*Judged* by `experiment/os10_time.sh`: an authority and a till on one wire,
pinned at 557 lines and identical on two runs -- three boots dated, two
with the authority gone (the dated entries stay dated and the later ones
are undated, with no date made up for them), an impostor with a good
signature of its own refused at the door and absent from the disk read
back, a line the power cut short that the witness reports and survives, an
authority whose clock will not answer and one with no link to answer on
(each says so and does not say it answers), and six audits that must fail;
by the unit tests and a probe that convicts each of the 31 mutants it
tries of them and the 44 it tries of the grammars' time rules
(`experiment/time_probe.sh`), and by a second probe that puts five bugs
back into what PID 1 does with a time, one at a time in a scratch copy,
and requires the scene to fail on a line of the section that names each
(`experiment/time_scene_probe.sh`). *Not built:* authenticated network time (NTS)
as a source, so an authority stands on a declared clock and on nothing else;
a fleet with more than one authority; a lower bound (a statement says no
later than, never how long before); an authority's key that is replaced
(the statements the old key signed are not taken by a fleet that no longer
enrols it); a limit on how often the authority answers, or a confinement of
the process that does; and a board's real clock, which is OS-5's to show --
the emulator's clock is a fixed base that runs with the virtual machine.

*The mirror, as built (MIR-1, 2026-10-19, STZ-OS-RULING-19).* A world's
records are a directory of its own (OWN-1), and the machine it runs on is
one machine. A MIRROR is a declared copy of that directory on another
member, over a link the fleet names, verified by the fleet's keys. The
machine that gives declares the directory (`MIRROR_OF`, which must lie in
the `STATE` of a world, so the court knows whose it is), the one device it
is given to (`MIRROR_FOR`, that device's public key) and the link and TCP
port it is given on (`MIRROR_SERVER`, a clause of a NETWORK); the machine
that keeps declares whom it takes from and whose word (`MIRROR_FROM`,
`MIRROR_KEY`), where it keeps the copy (`MIRROR_INTO`) and how often it
asks (`MIRROR_EVERY`), and a machine gives or keeps, never both. The fleet's
`MIRROR` (FROM, TO) pairs the two ends and the court holds the pair to
each other before anything boots: the address and port, the two enrolled
keys, a way there, and that no machine gives or takes a copy the file
never named. A keeper in another territory than the one the data stays in
is refused by the RESIDENCY the fleet already holds every disk to; the
mirror needed no rule of its own for it.
The source sends a challenge, the keeper answers with a request signed by
its device key over both nonces, and only a request that verifies under the
key the source was declared to give to is answered; anything else is
closed on, without a word. The answer is a LISTING the source signs (every
entry and the digest of every file, sorted, one spelling of each field,
cut for one device and one request) and then the bytes, each held to the
digest the signature covers as it is written. The walk of the directory
follows no link and gives only the files the WORLD owns, because the floor
reads the directory as root and the world can put anything in it: a hard
link to the machine's own key is a regular file with another owner, and is
refused for it. The keeper receives into a place of its own, reads what it
wrote back against the listing, and swaps it in with renames, so that a
power cut at any step leaves the last COMPLETE copy or none, and beside the
copy it keeps the signed listing it was verified against and one line
about its last attempt. `harb mirror check` (inside the keeper) and
`harb mirror verify` (anywhere, with the fleet file and no secret) re-read
the copy against the listing.
*Judged* by `experiment/os12_mirror.sh`: two machines on one wire,
enrolled by hand, a ledger of a few hundred kilobytes copied and read back
from both disks, a changed directory followed, and the negatives -- an
impostor answering from the source's address with a good signature of its
own and a forged file, a keeper that is not the device the source gives to,
a symbolic link in the directory, a file in the world's directory that is
the machine's own device key under another name (its bytes are found on no
disk of the keeper's), the source gone, a pull cut short at two different
steps, a copy changed on the keeper's disk, and both machines with the
disk behind the copy refused by the kernel -- plus eight refusals on the host;
by 23 tests on Linux (a real socket pair, a source that replays, lies or
stops half way, a swap cut at each step) and a probe that convicts each
mutant of them and of the two grammars' rules
(`experiment/mirror_probe.sh`). *Not built:* more than one mirror per
machine; confidentiality on the link (the bytes cross in the clear, and a
host at the source's address can relay the exchange and read the copy);
generations (the copy is the last complete one, which can also be the last
empty one); a delta (every pull moves
every byte, and needs room for a second copy while it swaps); freshness
beyond the request (a source that rolls its own directory back is its own
word); a restore verb; a confinement of the two children, which are the
floor's own code running as root; and anything but regular files and
directories.

*The roll call, as built (ROLL-1, 2026-10-20, STZ-OS-RULING-19).* A fleet's
machines keep signed records of their boots, and a fleet that names a time
authority has the entries dated; what it could not do was read the whole
set at once and say who had written since the last time anybody looked.
`harb roll <fleet> <dir> [--since <roll>]` takes the record each member was
brought -- `<member>.record` and the statements beside it -- and says, with
only what the fleet file holds, whether each is there, whether it is the
member's own and whole, how far it goes and what the authority said of it;
and, against the roll before, who WROTE (the roll's last entry is still in
the record, at the place that roll counted it, so the entries after it were
written after that entry), who has NOTHING NEW, whose record went
BACKWARDS or became another chain, and who was held and is ABSENT now, with
the entries, last entry and newest dated entry the last roll held of it:
what is lost is a line with numbers on it. "Since" is the previous roll's
last entry, named by the digest of the whole line (an entry's own hash is a
hash of public bytes, which two devices of one design share, so a rebuilt
card would be taken for the old one), and not a clock, because the floor's
dates are upper bounds ("no later than"). A member the roll could not hold
is not forgotten -- the roll keeps what it last held, and the time of the
roll that held it -- and a record that went backwards stays DIVERGED until
a roll is called again without `--since`, because accepting it is an act of
a person. An entry the authority dates before the roll that did not have it
says that roll was shown a copy older than it said (`--at` is the moment the
records were collected). A machine that stops declaring a journal, and a
member the fleet file stops naming, are said once; the second is a finding
when the roll still owed an answer for it. A record is written once per boot,
so a member that stays up has nothing new, and the roll names that state and
does not judge it. The roll is a file (`--out`), unsigned, which holds the
records' word, the caller's clock and the history of the calls (the same
records and the same roll before it, called at the same moment, make the same
one); it is written only if it reads back, to a file beside the one it
replaces, synced, and renamed over it.
*Judged* by `experiment/os13_roll.sh`, which runs the time seat's arc and
rolls over the till's record in eighteen sections (a roll that is not
brought the record and keeps what it held, a record that goes backwards and
stays flagged until accepted, a stale copy, an entry taken out, a statement
changed, a record cut at its end, a key nobody enrolled and a clock behind
the roll before it), pinned at 187 lines; by twenty-one tests and a probe that
convicts each of 89 mutants of the module (`experiment/roll_probe.sh`); and by
two readers with no stake, whose findings are each a case. *Not built:* the
collecting (the floor moves no record between machines; the mirror carries a
world's directory and not the floor's record, and a machine keeps one mirror,
so a witness cannot yet fetch from many), a heartbeat on a timer so that a live
member keeps writing, an alarm, and a roll that is signed.

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
*Status:* the reading is built (ROLL-1, 2026-10-20: `harb roll`, described under the mirror above); the collecting, per-world egress, the packet filter and the evidence page are not.

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
  *Amended 2026-10-18 (STZ-OS-RULING-19), when the year's strikes on
  data centers were read against this ladder (`site/datacenters.html`):
  a MIRROR -- a declared copy of a world's own directory on another
  member, over a declared link, verified by the fleet's keys -- is
  ordered and will be the floor's. A distributed filesystem is still
  not: the floor copies and verifies files between declared places, and
  what a consistent copy IS stays the application's.*
  *Built 2026-10-19 (MIR-1): `MIRROR_OF`, `MIRROR_FOR` and `MIRROR_SERVER`
  on the machine that gives, `MIRROR_FROM`, `MIRROR_KEY`, `MIRROR_INTO` and
  `MIRROR_EVERY` on the one that keeps, and fleet v0.5's `MIRROR` that pairs
  them; the sentence above is true of what was built, and still true of
  everything else.*
- **No knowledge of where a box really is.** The floor has no way to tell a
  room from a country. `TERRITORY` on a member says where it stands and
  `RESIDENCY` says where the fleet's data stays (TERR-1, 2026-10-19,
  STZ-OS-RULING-19): the court refuses, before any boot, a member that keeps
  a disk and stands anywhere else, and the roll names the law and whom it
  binds. What is judged is the DECLARATION -- the box in the wrong country is
  refused where it is declared and not found where it is plugged in -- and
  whoever enrols a member vouches for where it stands as for its key. The
  law is the fleet's whole, because a fleet does not yet say which world
  runs on which member, so it binds every writable persistent disk; one
  territory per fleet, and no law that keeps a machine OUT of a place.
- **No second grammar.** A cloud is fleet v0.5 -- routes, doors, residency,
  copies, placement, rollout added to the kinds a fleet file may contain -- never a
  third file. A file is judged by which kinds it may contain.
  *Amended 2026-10-04, the day it was written, when rung 1's first
  session read the code (PLC-1): the sentence is true of the SET and
  false of the solution. A pack -- the solution's own file, the thing a
  fleet places -- is a third file TYPE of the same language, judged by
  the kinds it may carry (SERVICE and USER), as the fleet file is; it is
  not a second grammar, and the set's routes, placement and rollout
  still belong to one fleet file. The plan the author approved named
  the pack file; this paragraph said otherwise, and the code is the
  tie-break.*

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

- Rungs 1 and 2 are built, for one server and one forwarder on emulated
  machines (PLC-1 and SRV-2, then FWD-1, 2026-10-04: the pack file,
  `harb place`, RingServ placed and booted; `FORWARD`, fleet v0.2 and a
  till reaching it across two links), and for no customer's: the
  Commons is not placed, and RingServ is the stand-in. Rung 3's time half
  is built too (TIME-1, 2026-10-05), in the emulator, where the clock is a
  fixed base that runs with the virtual machine; no other rung is built.
  Today there is no front and no board's clock has been read, a placed
  server is reached over plain HTTP from the links of its own cloud and
  from nowhere else,
  a route is a way both ways, and the packet filter that would say
  otherwise does not exist.
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
  for the world, because the authority it attests must be real. The time
  half of rung 3 is built and judged all the same, against a clock the
  emulator hands the authority (a fixed base that runs with the virtual
  machine), and says so: what is shown is the mechanism, that a statement
  is an authority's word, bound to one record, checked with a public key.
  That the clock on a board keeps time is the first board's to show.

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

*Amended 2026-10-04: the first part is done.* The session that took the
placement half (PLC-1) found that the "pack manifest" is a SERVICE and
the identities it runs as, in the machine language, because a SERVICE
already says what it needs (`NEEDS`), which mounts it sees (`SEES`), when
it is serving (`READY`, `HEALTH`) and its budget; so the manifest is the
pack, hand-written, and `harb place` is the judge. A manifest has no
port and no reach per world because a SERVICE has neither (rung 6). What
is left of rung 1 is what the paragraph above says needs somebody
else: the server's program and its own statement of what it needs.

*Amended again the same day, after the author named the server:* the
second part is done for RingServ (SRV-2). Its needs were read from its
repository at origin/main 002ba21 and not asked for: a listening socket,
a store, threads, a clock, and no environment. What it could not say for
itself is that it is serving, so a program says it (`harb ready`); the
read, the adapter, the pack, the machine and the pinned boot are in
`experiment/PROTOCOL.md` under SRV-2. The Commons, when its desk hands it
over, is placed the same way, and the pack changes.

*And the second rung, taken the same day, after it (FWD-1).* It needed
a grammar change, as this section said rung 2 would: a clause on the
machine, a kind in the fleet, and a bound on what a boot may call a
link (a loopback is declared and is not one). It is the first rung whose
judge is a set of machines and not one: `experiment/os8_links.sh`, three
machines on two wires, where a till reaches the server it names through
a box that is the way between its link and the server's. The pack of
rung 1 is unchanged and is placed on the core machine as it was.
